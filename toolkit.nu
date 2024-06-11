export def "read index" [] {
  let l = http get --raw "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/index.html"
  let pre = $l | parse "{before}<pre>{pre}</pre>{after}" | get pre.0
  let index = $pre | parse --regex '<a href="(?<url>[^"]+)">libwebp-(?<version>\d+\.\d+\.\d+(?:-rc\d+)?)(?:-(?<platform>[^"]+))?\.(?<extension>zip|tar.gz)</a>\s+(?<date>[^ ]+)\s+(?<size>\d+(?:\.\d+)?\w+)\s+'
  $index | update date { |r| $r.date | into datetime } | update size { |r| $r.size | into filesize } | update url { |r| $"https:($r.url)" } | sort-by date
}

export def "install" [platform: string, --version: string = "latest"] {
  print "Reading index.html from webp releases"
  let index = read index
  # check if the platform is valid
  let platforms = $index | uniq-by platform | get platform
  if ($platform not-in $platforms) {
    print $"Invalid platform ($platform), valid platforms are ($platforms | str join ', ')"
    return
  }
  let version_candidates = if $version == "latest" {
    $index | where platform == $platform
  } else {
    $index | where platform == $platform | where version == $version 
  } | sort-by date

  if ($version_candidates | is-empty) {
    print $"No version found for ($platform) and ($version)"
    return
  }

  let version = $version_candidates | last

  print $"Downloading ($version.url | path split | last)..."

  let path = [$nu.temp-path "libwebp" ($version.version | str replace -a '.' '_') $"libwebp.($version.extension)"] | path join
  mkdir ($path | path dirname)
  http get --raw $version.url | save $path -f

  let dest = $"libraries/webp" | path expand

  print $"Extracting ($path) to ($dest)..."

  mkdir $dest

  if ($version.extension == "zip") {
    7z x $path $"-o($dest)"
  } else if ($version.extension == "tar.gz") {
    tar xzf $path -C $dest
  }

  print "Done!"
}

export def "current version" []: any -> string {
  open pubspec.yaml | get libwebp.version | str trim
}

export def "install version" [version: string, --temp: string = "temp"]: any -> string {
  # read the manifest file
  let manifest_path = [$temp manifest.yaml] | path join
  let manifest = if ($manifest_path | path exists) { open $manifest_path } else { {} }
  let installed_version = $manifest | get -i version 
  let installed_path = $manifest | get -i path
  if ($installed_version != null and $installed_version == $version and $installed_path != null) {
    print $"libwebp ($version) is already installed at ($installed_path)"
    return $temp | path join $installed_path
  }
  mkdir $temp
  let url = $"https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-($version).tar.gz"
  let tar_path = [$temp "libwebp.tar.gz"] | path join
  print $"Downloading libwebp ($version) from ($url) to ($tar_path)..."
  http get --raw $url | save $tar_path -f
  print $"Extracting libwebp to ($temp)..."
  tar xzf $tar_path -C $temp
  let extracted = [$temp $"libwebp-($version)"] | path join
  let libwebp = [$temp "libwebp"] | path join
  rm -rf $libwebp
  mv -vf $extracted $libwebp
  # remove the tar file
  rm -f $tar_path
  {version: ($version), path: $libwebp} | save $manifest_path -f
  return $libwebp
}

export def "build windows" [--all] {
  let dev_cmd_path = 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat' | str replace -a " " "^ "
  print $"Using ($dev_cmd_path) to build libwebp..."
  let curr = $env.PWD
  
  let target_version = current version
  let libwebp = install version $target_version
  let output = [$curr libwebp_flutter_libs windows] | path join | path expand
  mkdir $output

  let targets = if $all {
    "all"
  } else {
    ""
  }

  print $"Building libwebp in ($libwebp) to ($output)..."
  with-env {VSCMD_DEBUG:0} {
    do {
      cd $libwebp
      cmd.exe /c $'($dev_cmd_path) -startdir=none -arch=x64 -host_arch=x64 -no_logo & echo %cd% & nmake /f Makefile.vc CFG=release-dynamic RTLIBCFG=dynamic OBJDIR=($output) ($targets)'
    }
  }
}

export def "gen" [] {
  let installed = install version (current version)
  do {
    cd packages/libwebp/
    dart run ffigen --config ffigen.yaml
  }
}