#include <stdint.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreGraphics/CGImage.h>
#import <CoreGraphics/CGAffineTransform.h>

#if !__has_feature(objc_arc)
#error "This file must be compiled with ARC enabled"
#endif

typedef struct {
  int64_t version;
  void* (*newWaiter)(void);
  void (*awaitWaiter)(void*);
  void* (*currentIsolate)(void);
  void (*enterIsolate)(void*);
  void (*exitIsolate)(void);
  int64_t (*getMainPortId)(void);
  bool (*getCurrentThreadOwnsIsolate)(int64_t);
} DOBJC_Context;

id objc_retainBlock(id);

#define BLOCKING_BLOCK_IMPL(ctx, BLOCK_SIG, INVOKE_DIRECT, INVOKE_LISTENER)    \
  assert(ctx->version >= 1);                                                   \
  void* targetIsolate = ctx->currentIsolate();                                 \
  int64_t targetPort = ctx->getMainPortId == NULL ? 0 : ctx->getMainPortId();  \
  return BLOCK_SIG {                                                           \
    void* currentIsolate = ctx->currentIsolate();                              \
    bool mayEnterIsolate =                                                     \
        currentIsolate == NULL &&                                              \
        ctx->getCurrentThreadOwnsIsolate != NULL &&                            \
        ctx->getCurrentThreadOwnsIsolate(targetPort);                          \
    if (currentIsolate == targetIsolate || mayEnterIsolate) {                  \
      if (mayEnterIsolate) {                                                   \
        ctx->enterIsolate(targetIsolate);                                      \
      }                                                                        \
      INVOKE_DIRECT;                                                           \
      if (mayEnterIsolate) {                                                   \
        ctx->exitIsolate();                                                    \
      }                                                                        \
    } else {                                                                   \
      void* waiter = ctx->newWaiter();                                         \
      INVOKE_LISTENER;                                                         \
      ctx->awaitWaiter(waiter);                                                \
    }                                                                          \
  };


typedef void  (^ListenerTrampoline)(struct CGPathElement * arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline _CoreGraphicsBindings_wrapListenerBlock_1ctgxtl(ListenerTrampoline block) NS_RETURNS_RETAINED {
  return ^void(struct CGPathElement * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^BlockingTrampoline)(void * waiter, struct CGPathElement * arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline _CoreGraphicsBindings_wrapBlockingBlock_1ctgxtl(
    BlockingTrampoline block, BlockingTrampoline listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(struct CGPathElement * arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef void  (^ListenerTrampoline_1)();
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_1 _CoreGraphicsBindings_wrapListenerBlock_1pl9qdv(ListenerTrampoline_1 block) NS_RETURNS_RETAINED {
  return ^void() {
    objc_retainBlock(block);
    block();
  };
}

typedef void  (^BlockingTrampoline_1)(void * waiter);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_1 _CoreGraphicsBindings_wrapBlockingBlock_1pl9qdv(
    BlockingTrampoline_1 block, BlockingTrampoline_1 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(), {
    objc_retainBlock(block);
    block(nil);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter);
  });
}

typedef void  (^ListenerTrampoline_2)(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_2 _CoreGraphicsBindings_wrapListenerBlock_tg5tbv(ListenerTrampoline_2 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^BlockingTrampoline_2)(void * waiter, struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_2 _CoreGraphicsBindings_wrapBlockingBlock_tg5tbv(
    BlockingTrampoline_2 block, BlockingTrampoline_2 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^ListenerTrampoline_3)(struct __CFRunLoopTimer * arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_3 _CoreGraphicsBindings_wrapListenerBlock_1dqvvol(ListenerTrampoline_3 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopTimer * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^BlockingTrampoline_3)(void * waiter, struct __CFRunLoopTimer * arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_3 _CoreGraphicsBindings_wrapBlockingBlock_1dqvvol(
    BlockingTrampoline_3 block, BlockingTrampoline_3 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(struct __CFRunLoopTimer * arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef id  (^ProtocolTrampoline)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
id  _CoreGraphicsBindings_protocolTrampoline_1mbt9g9(id target, void * sel) {
  return ((ProtocolTrampoline)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

Protocol* _CoreGraphicsBindings_OS_os_workgroup_interval(void) { return @protocol(OS_os_workgroup_interval); }

Protocol* _CoreGraphicsBindings_OS_os_workgroup_parallel(void) { return @protocol(OS_os_workgroup_parallel); }

Protocol* _CoreGraphicsBindings_OS_dispatch_object(void) { return @protocol(OS_dispatch_object); }

Protocol* _CoreGraphicsBindings_OS_dispatch_queue(void) { return @protocol(OS_dispatch_queue); }

Protocol* _CoreGraphicsBindings_OS_dispatch_queue_global(void) { return @protocol(OS_dispatch_queue_global); }

Protocol* _CoreGraphicsBindings_OS_dispatch_queue_serial_executor(void) { return @protocol(OS_dispatch_queue_serial_executor); }

Protocol* _CoreGraphicsBindings_OS_dispatch_queue_serial(void) { return @protocol(OS_dispatch_queue_serial); }

Protocol* _CoreGraphicsBindings_OS_dispatch_queue_main(void) { return @protocol(OS_dispatch_queue_main); }

Protocol* _CoreGraphicsBindings_OS_dispatch_queue_concurrent(void) { return @protocol(OS_dispatch_queue_concurrent); }

typedef void  (^ListenerTrampoline_4)(size_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_4 _CoreGraphicsBindings_wrapListenerBlock_6enxqz(ListenerTrampoline_4 block) NS_RETURNS_RETAINED {
  return ^void(size_t arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^BlockingTrampoline_4)(void * waiter, size_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_4 _CoreGraphicsBindings_wrapBlockingBlock_6enxqz(
    BlockingTrampoline_4 block, BlockingTrampoline_4 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(size_t arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

Protocol* _CoreGraphicsBindings_OS_dispatch_queue_attr(void) { return @protocol(OS_dispatch_queue_attr); }

Protocol* _CoreGraphicsBindings_OS_dispatch_source(void) { return @protocol(OS_dispatch_source); }

Protocol* _CoreGraphicsBindings_OS_dispatch_group(void) { return @protocol(OS_dispatch_group); }

Protocol* _CoreGraphicsBindings_OS_dispatch_semaphore(void) { return @protocol(OS_dispatch_semaphore); }

Protocol* _CoreGraphicsBindings_OS_dispatch_data(void) { return @protocol(OS_dispatch_data); }

typedef void  (^ListenerTrampoline_5)(id arg0, int arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_5 _CoreGraphicsBindings_wrapListenerBlock_18kzm6a(ListenerTrampoline_5 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, int arg1) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1);
  };
}

typedef void  (^BlockingTrampoline_5)(void * waiter, id arg0, int arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_5 _CoreGraphicsBindings_wrapBlockingBlock_18kzm6a(
    BlockingTrampoline_5 block, BlockingTrampoline_5 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, int arg1), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1);
  });
}

Protocol* _CoreGraphicsBindings_OS_dispatch_io(void) { return @protocol(OS_dispatch_io); }

typedef void  (^ListenerTrampoline_6)(int arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_6 _CoreGraphicsBindings_wrapListenerBlock_9o8504(ListenerTrampoline_6 block) NS_RETURNS_RETAINED {
  return ^void(int arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^BlockingTrampoline_6)(void * waiter, int arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_6 _CoreGraphicsBindings_wrapBlockingBlock_9o8504(
    BlockingTrampoline_6 block, BlockingTrampoline_6 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(int arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef void  (^ListenerTrampoline_7)(BOOL arg0, id arg1, int arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_7 _CoreGraphicsBindings_wrapListenerBlock_og5b6y(ListenerTrampoline_7 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0, id arg1, int arg2) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), arg2);
  };
}

typedef void  (^BlockingTrampoline_7)(void * waiter, BOOL arg0, id arg1, int arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_7 _CoreGraphicsBindings_wrapBlockingBlock_og5b6y(
    BlockingTrampoline_7 block, BlockingTrampoline_7 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(BOOL arg0, id arg1, int arg2), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), arg2);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), arg2);
  });
}

Protocol* _CoreGraphicsBindings_OS_dispatch_workloop(void) { return @protocol(OS_dispatch_workloop); }
#undef BLOCKING_BLOCK_IMPL
