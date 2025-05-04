

ffi-gen target:
  #!/usr/bin/env bash
  set -euo pipefail
  project_dir="packages/{{target}}"
  cd "$project_dir"
  for file in $(find ffigen -name "*.yml" -o -name "*.yaml"); do
    echo "Generating FFI bindings for $file"
    dart run ffigen --config "$file" -v severe
  done