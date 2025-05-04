#include <stdint.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <Foundation/Foundation.h>

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


typedef BOOL  (^ProtocolTrampoline)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _FoundationBindings_protocolTrampoline_e3qsqz(id target, void * sel) {
  return ((ProtocolTrampoline)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^ListenerTrampoline)(void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline _FoundationBindings_wrapListenerBlock_ovsamd(ListenerTrampoline block) NS_RETURNS_RETAINED {
  return ^void(void * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^BlockingTrampoline)(void * waiter, void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline _FoundationBindings_wrapBlockingBlock_ovsamd(
    BlockingTrampoline block, BlockingTrampoline listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef void  (^ProtocolTrampoline_1)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_ovsamd(id target, void * sel) {
  return ((ProtocolTrampoline_1)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

Protocol* _FoundationBindings_NSDiscardableContent(void) { return @protocol(NSDiscardableContent); }

typedef id  (^ProtocolTrampoline_2)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_1mbt9g9(id target, void * sel) {
  return ((ProtocolTrampoline_2)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^ListenerTrampoline_1)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_1 _FoundationBindings_wrapListenerBlock_pfv6jd(ListenerTrampoline_1 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^BlockingTrampoline_1)(void * waiter, id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_1 _FoundationBindings_wrapBlockingBlock_pfv6jd(
    BlockingTrampoline_1 block, BlockingTrampoline_1 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, id arg1), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1));
  });
}

typedef void  (^ListenerTrampoline_2)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_2 _FoundationBindings_wrapListenerBlock_1b3bb6a(ListenerTrampoline_2 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retainBlock(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  };
}

typedef void  (^BlockingTrampoline_2)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_2 _FoundationBindings_wrapBlockingBlock_1b3bb6a(
    BlockingTrampoline_2 block, BlockingTrampoline_2 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, id arg1, id arg2), {
    objc_retainBlock(block);
    block(nil, objc_retainBlock(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, objc_retainBlock(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  });
}

typedef id  (^ProtocolTrampoline_3)(void * sel, id arg1, id arg2, id * arg3);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_10z9f5k(id target, void * sel, id arg1, id arg2, id * arg3) {
  return ((ProtocolTrampoline_3)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

typedef NSItemProviderRepresentationVisibility  (^ProtocolTrampoline_4)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
NSItemProviderRepresentationVisibility  _FoundationBindings_protocolTrampoline_1ldqghh(id target, void * sel, id arg1) {
  return ((ProtocolTrampoline_4)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef void  (^ListenerTrampoline_3)();
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_3 _FoundationBindings_wrapListenerBlock_1pl9qdv(ListenerTrampoline_3 block) NS_RETURNS_RETAINED {
  return ^void() {
    objc_retainBlock(block);
    block();
  };
}

typedef void  (^BlockingTrampoline_3)(void * waiter);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_3 _FoundationBindings_wrapBlockingBlock_1pl9qdv(
    BlockingTrampoline_3 block, BlockingTrampoline_3 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(), {
    objc_retainBlock(block);
    block(nil);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter);
  });
}

typedef id  (^ProtocolTrampoline_5)(void * sel, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_1q0i84(id target, void * sel, id arg1, id arg2) {
  return ((ProtocolTrampoline_5)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

typedef id  (^ProtocolTrampoline_6)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_xr62hr(id target, void * sel, id arg1) {
  return ((ProtocolTrampoline_6)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef unsigned long  (^ProtocolTrampoline_7)(void * sel, NSFastEnumerationState * arg1, id * arg2, unsigned long arg3);
__attribute__((visibility("default"))) __attribute__((used))
unsigned long  _FoundationBindings_protocolTrampoline_17ap02x(id target, void * sel, NSFastEnumerationState * arg1, id * arg2, unsigned long arg3) {
  return ((ProtocolTrampoline_7)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

Protocol* _FoundationBindings_NSProgressReporting(void) { return @protocol(NSProgressReporting); }

typedef void  (^ListenerTrampoline_4)(id arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_4 _FoundationBindings_wrapListenerBlock_xtuoz7(ListenerTrampoline_4 block) NS_RETURNS_RETAINED {
  return ^void(id arg0) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0));
  };
}

typedef void  (^BlockingTrampoline_4)(void * waiter, id arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_4 _FoundationBindings_wrapBlockingBlock_xtuoz7(
    BlockingTrampoline_4 block, BlockingTrampoline_4 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0));
  });
}

typedef void  (^ListenerTrampoline_5)(id arg0, struct _NSRange arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_5 _FoundationBindings_wrapListenerBlock_1a22wz(ListenerTrampoline_5 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, struct _NSRange arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  };
}

typedef void  (^BlockingTrampoline_5)(void * waiter, id arg0, struct _NSRange arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_5 _FoundationBindings_wrapBlockingBlock_1a22wz(
    BlockingTrampoline_5 block, BlockingTrampoline_5 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, struct _NSRange arg1, BOOL * arg2), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  });
}

typedef void  (^ListenerTrampoline_6)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_6 _FoundationBindings_wrapListenerBlock_18v1jvf(ListenerTrampoline_6 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^BlockingTrampoline_6)(void * waiter, void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_6 _FoundationBindings_wrapBlockingBlock_18v1jvf(
    BlockingTrampoline_6 block, BlockingTrampoline_6 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  });
}

typedef void  (^ProtocolTrampoline_8)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_18v1jvf(id target, void * sel, id arg1) {
  return ((ProtocolTrampoline_8)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef void  (^ListenerTrampoline_7)(BOOL arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_7 _FoundationBindings_wrapListenerBlock_1s56lr9(ListenerTrampoline_7 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^BlockingTrampoline_7)(void * waiter, BOOL arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_7 _FoundationBindings_wrapBlockingBlock_1s56lr9(
    BlockingTrampoline_7 block, BlockingTrampoline_7 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(BOOL arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef void  (^ListenerTrampoline_8)(id arg0, BOOL arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_8 _FoundationBindings_wrapListenerBlock_1uqbrux(ListenerTrampoline_8 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, BOOL arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  };
}

typedef void  (^BlockingTrampoline_8)(void * waiter, id arg0, BOOL arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_8 _FoundationBindings_wrapBlockingBlock_1uqbrux(
    BlockingTrampoline_8 block, BlockingTrampoline_8 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, BOOL arg1, BOOL * arg2), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  });
}

typedef NSRoundingMode  (^ProtocolTrampoline_9)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
NSRoundingMode  _FoundationBindings_protocolTrampoline_5cb1bj(id target, void * sel) {
  return ((ProtocolTrampoline_9)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef short  (^ProtocolTrampoline_10)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
short  _FoundationBindings_protocolTrampoline_p984hf(id target, void * sel) {
  return ((ProtocolTrampoline_10)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef id  (^ProtocolTrampoline_11)(void * sel, struct objc_selector * arg1, NSCalculationError arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_738w24(id target, void * sel, struct objc_selector * arg1, NSCalculationError arg2, id arg3, id arg4) {
  return ((ProtocolTrampoline_11)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

Protocol* _FoundationBindings_NSDecimalNumberBehaviors(void) { return @protocol(NSDecimalNumberBehaviors); }

typedef BOOL  (^ProtocolTrampoline_12)(void * sel, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _FoundationBindings_protocolTrampoline_jk8du5(id target, void * sel, id arg1, id arg2, id arg3) {
  return ((ProtocolTrampoline_12)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

typedef BOOL  (^ProtocolTrampoline_13)(void * sel, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _FoundationBindings_protocolTrampoline_1em3l8z(id target, void * sel, id arg1, id arg2, id arg3, id arg4) {
  return ((ProtocolTrampoline_13)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

typedef BOOL  (^ProtocolTrampoline_14)(void * sel, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _FoundationBindings_protocolTrampoline_2n06mv(id target, void * sel, id arg1, id arg2) {
  return ((ProtocolTrampoline_14)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

Protocol* _FoundationBindings_NSFileManagerDelegate(void) { return @protocol(NSFileManagerDelegate); }

typedef id  (^ProtocolTrampoline_15)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_wpy7aa(id target, void * sel, id arg1) {
  return ((ProtocolTrampoline_15)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

Protocol* _FoundationBindings_NSXPCProxyCreating(void) { return @protocol(NSXPCProxyCreating); }

typedef id  (^ProtocolTrampoline_16)(void * sel, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_zi5eed(id target, void * sel, id arg1, id arg2) {
  return ((ProtocolTrampoline_16)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

typedef void  (^ListenerTrampoline_9)(void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_9 _FoundationBindings_wrapListenerBlock_fjrv01(ListenerTrampoline_9 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  };
}

typedef void  (^BlockingTrampoline_9)(void * waiter, void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_9 _FoundationBindings_wrapBlockingBlock_fjrv01(
    BlockingTrampoline_9 block, BlockingTrampoline_9 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  });
}

typedef void  (^ProtocolTrampoline_17)(void * sel, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_fjrv01(id target, void * sel, id arg1, id arg2) {
  return ((ProtocolTrampoline_17)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

typedef void  (^ListenerTrampoline_10)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_10 _FoundationBindings_wrapListenerBlock_1tz5yf(ListenerTrampoline_10 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3));
  };
}

typedef void  (^BlockingTrampoline_10)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_10 _FoundationBindings_wrapBlockingBlock_1tz5yf(
    BlockingTrampoline_10 block, BlockingTrampoline_10 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2, id arg3), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3));
  });
}

typedef void  (^ProtocolTrampoline_18)(void * sel, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_1tz5yf(id target, void * sel, id arg1, id arg2, id arg3) {
  return ((ProtocolTrampoline_18)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

Protocol* _FoundationBindings_NSKeyedArchiverDelegate(void) { return @protocol(NSKeyedArchiverDelegate); }

typedef id  (^ProtocolTrampoline_19)(void * sel, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_1yw2rcr(id target, void * sel, id arg1, id arg2, id arg3) {
  return ((ProtocolTrampoline_19)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

typedef id  (^ProtocolTrampoline_20)(void * sel, id arg1, id arg2 __attribute__((ns_consumed)));
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_1p0fswn(id target, void * sel, id arg1, id arg2 __attribute__((ns_consumed))) {
  return ((ProtocolTrampoline_20)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

Protocol* _FoundationBindings_NSKeyedUnarchiverDelegate(void) { return @protocol(NSKeyedUnarchiverDelegate); }

Protocol* _FoundationBindings_NSLocking(void) { return @protocol(NSLocking); }

Protocol* _FoundationBindings_NSPortDelegate(void) { return @protocol(NSPortDelegate); }

typedef BOOL  (^ProtocolTrampoline_21)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _FoundationBindings_protocolTrampoline_3su7tt(id target, void * sel, id arg1) {
  return ((ProtocolTrampoline_21)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef id  (^ProtocolTrampoline_22)(void * sel, struct objc_selector * arg1);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_50as9u(id target, void * sel, struct objc_selector * arg1) {
  return ((ProtocolTrampoline_22)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef id  (^ProtocolTrampoline_23)(void * sel, struct objc_selector * arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_1mllhpc(id target, void * sel, struct objc_selector * arg1, id arg2) {
  return ((ProtocolTrampoline_23)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

typedef id  (^ProtocolTrampoline_24)(void * sel, struct objc_selector * arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_c7gk2u(id target, void * sel, struct objc_selector * arg1, id arg2, id arg3) {
  return ((ProtocolTrampoline_24)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

typedef unsigned long  (^ProtocolTrampoline_25)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
unsigned long  _FoundationBindings_protocolTrampoline_1ckyi24(id target, void * sel) {
  return ((ProtocolTrampoline_25)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef struct _NSZone *  (^ProtocolTrampoline_26)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
struct _NSZone *  _FoundationBindings_protocolTrampoline_1a8cl66(id target, void * sel) {
  return ((ProtocolTrampoline_26)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

Protocol* _FoundationBindings_NSConnectionDelegate(void) { return @protocol(NSConnectionDelegate); }

typedef void  (^ListenerTrampoline_11)(void * arg0, void * arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_11 _FoundationBindings_wrapListenerBlock_1037nh9(ListenerTrampoline_11 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, void * arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^BlockingTrampoline_11)(void * waiter, void * arg0, void * arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_11 _FoundationBindings_wrapBlockingBlock_1037nh9(
    BlockingTrampoline_11 block, BlockingTrampoline_11 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, void * arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^ProtocolTrampoline_27)(void * sel, void * arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_1037nh9(id target, void * sel, void * arg1) {
  return ((ProtocolTrampoline_27)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

Protocol* _FoundationBindings_NSMachPortDelegate(void) { return @protocol(NSMachPortDelegate); }

typedef void  (^ListenerTrampoline_12)(id arg0, NSMatchingFlags arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_12 _FoundationBindings_wrapListenerBlock_6jvo9y(ListenerTrampoline_12 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, NSMatchingFlags arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  };
}

typedef void  (^BlockingTrampoline_12)(void * waiter, id arg0, NSMatchingFlags arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_12 _FoundationBindings_wrapBlockingBlock_6jvo9y(
    BlockingTrampoline_12 block, BlockingTrampoline_12 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, NSMatchingFlags arg1, BOOL * arg2), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  });
}

typedef void  (^ListenerTrampoline_13)(void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_13 _FoundationBindings_wrapListenerBlock_8jfq1p(ListenerTrampoline_13 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4));
  };
}

typedef void  (^BlockingTrampoline_13)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_13 _FoundationBindings_wrapBlockingBlock_8jfq1p(
    BlockingTrampoline_13 block, BlockingTrampoline_13 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2, id arg3, id arg4), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4));
  });
}

typedef void  (^ProtocolTrampoline_28)(void * sel, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_8jfq1p(id target, void * sel, id arg1, id arg2, id arg3, id arg4) {
  return ((ProtocolTrampoline_28)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

typedef void  (^ListenerTrampoline_14)(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_14 _FoundationBindings_wrapListenerBlock_m09tr7(ListenerTrampoline_14 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4), (__bridge id)(__bridge_retained void*)(arg5));
  };
}

typedef void  (^BlockingTrampoline_14)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_14 _FoundationBindings_wrapBlockingBlock_m09tr7(
    BlockingTrampoline_14 block, BlockingTrampoline_14 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4), (__bridge id)(__bridge_retained void*)(arg5));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4), (__bridge id)(__bridge_retained void*)(arg5));
  });
}

typedef void  (^ProtocolTrampoline_29)(void * sel, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_m09tr7(id target, void * sel, id arg1, id arg2, id arg3, id arg4, id arg5) {
  return ((ProtocolTrampoline_29)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4, arg5);
}

Protocol* _FoundationBindings_NSXMLParserDelegate(void) { return @protocol(NSXMLParserDelegate); }

Protocol* _FoundationBindings_NSXPCListenerDelegate(void) { return @protocol(NSXPCListenerDelegate); }

Protocol* _FoundationBindings_NSCacheDelegate(void) { return @protocol(NSCacheDelegate); }

Protocol* _FoundationBindings_NSExtensionRequestHandling(void) { return @protocol(NSExtensionRequestHandling); }

typedef void  (^ListenerTrampoline_15)(id arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_15 _FoundationBindings_wrapListenerBlock_f167m6(ListenerTrampoline_15 block) NS_RETURNS_RETAINED {
  return ^void(id arg0) {
    objc_retainBlock(block);
    block(objc_retainBlock(arg0));
  };
}

typedef void  (^BlockingTrampoline_15)(void * waiter, id arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_15 _FoundationBindings_wrapBlockingBlock_f167m6(
    BlockingTrampoline_15 block, BlockingTrampoline_15 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0), {
    objc_retainBlock(block);
    block(nil, objc_retainBlock(arg0));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, objc_retainBlock(arg0));
  });
}

typedef void  (^ListenerTrampoline_16)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_16 _FoundationBindings_wrapListenerBlock_1l4hxwm(ListenerTrampoline_16 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retainBlock(arg1));
  };
}

typedef void  (^BlockingTrampoline_16)(void * waiter, void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_16 _FoundationBindings_wrapBlockingBlock_1l4hxwm(
    BlockingTrampoline_16 block, BlockingTrampoline_16 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1), {
    objc_retainBlock(block);
    block(nil, arg0, objc_retainBlock(arg1));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, objc_retainBlock(arg1));
  });
}

typedef void  (^ProtocolTrampoline_30)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_1l4hxwm(id target, void * sel, id arg1) {
  return ((ProtocolTrampoline_30)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef void  (^ListenerTrampoline_17)(void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_17 _FoundationBindings_wrapListenerBlock_jk1ljc(ListenerTrampoline_17 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), objc_retainBlock(arg2));
  };
}

typedef void  (^BlockingTrampoline_17)(void * waiter, void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_17 _FoundationBindings_wrapBlockingBlock_jk1ljc(
    BlockingTrampoline_17 block, BlockingTrampoline_17 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), objc_retainBlock(arg2));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), objc_retainBlock(arg2));
  });
}

typedef void  (^ProtocolTrampoline_31)(void * sel, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_jk1ljc(id target, void * sel, id arg1, id arg2) {
  return ((ProtocolTrampoline_31)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

Protocol* _FoundationBindings_NSFilePresenter(void) { return @protocol(NSFilePresenter); }

typedef void  (^ListenerTrampoline_18)(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_18 _FoundationBindings_wrapListenerBlock_lmc3p5(ListenerTrampoline_18 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1, arg2, arg3);
  };
}

typedef void  (^BlockingTrampoline_18)(void * waiter, id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_18 _FoundationBindings_wrapBlockingBlock_lmc3p5(
    BlockingTrampoline_18 block, BlockingTrampoline_18 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2, arg3);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2, arg3);
  });
}

Protocol* _FoundationBindings_NSMetadataQueryDelegate(void) { return @protocol(NSMetadataQueryDelegate); }

typedef void  (^ListenerTrampoline_19)(id arg0, unsigned long arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_19 _FoundationBindings_wrapListenerBlock_1p9ui4q(ListenerTrampoline_19 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, unsigned long arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  };
}

typedef void  (^BlockingTrampoline_19)(void * waiter, id arg0, unsigned long arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_19 _FoundationBindings_wrapBlockingBlock_1p9ui4q(
    BlockingTrampoline_19 block, BlockingTrampoline_19 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, unsigned long arg1, BOOL * arg2), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  });
}

Protocol* _FoundationBindings_NSNetServiceDelegate(void) { return @protocol(NSNetServiceDelegate); }

typedef void  (^ListenerTrampoline_20)(void * arg0, id arg1, id arg2, BOOL arg3);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_20 _FoundationBindings_wrapListenerBlock_8acz2h(ListenerTrampoline_20 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, BOOL arg3) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3);
  };
}

typedef void  (^BlockingTrampoline_20)(void * waiter, void * arg0, id arg1, id arg2, BOOL arg3);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_20 _FoundationBindings_wrapBlockingBlock_8acz2h(
    BlockingTrampoline_20 block, BlockingTrampoline_20 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2, BOOL arg3), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3);
  });
}

typedef void  (^ProtocolTrampoline_32)(void * sel, id arg1, id arg2, BOOL arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_8acz2h(id target, void * sel, id arg1, id arg2, BOOL arg3) {
  return ((ProtocolTrampoline_32)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

Protocol* _FoundationBindings_NSNetServiceBrowserDelegate(void) { return @protocol(NSNetServiceBrowserDelegate); }

Protocol* _FoundationBindings_NSUserActivityDelegate(void) { return @protocol(NSUserActivityDelegate); }

typedef void  (^ListenerTrampoline_21)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_21 _FoundationBindings_wrapListenerBlock_r8gdi7(ListenerTrampoline_21 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  };
}

typedef void  (^BlockingTrampoline_21)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_21 _FoundationBindings_wrapBlockingBlock_r8gdi7(
    BlockingTrampoline_21 block, BlockingTrampoline_21 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, id arg1, id arg2), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  });
}

typedef void  (^ListenerTrampoline_22)(NSBackgroundActivityResult arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_22 _FoundationBindings_wrapListenerBlock_10ssdng(ListenerTrampoline_22 block) NS_RETURNS_RETAINED {
  return ^void(NSBackgroundActivityResult arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^BlockingTrampoline_22)(void * waiter, NSBackgroundActivityResult arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_22 _FoundationBindings_wrapBlockingBlock_10ssdng(
    BlockingTrampoline_22 block, BlockingTrampoline_22 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(NSBackgroundActivityResult arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef struct _NSRange  (^ProtocolTrampoline_33)(void * sel, id arg1, id arg2, id arg3, long * arg4, BOOL arg5);
__attribute__((visibility("default"))) __attribute__((used))
struct _NSRange  _FoundationBindings_protocolTrampoline_1j6oadz(id target, void * sel, id arg1, id arg2, id arg3, long * arg4, BOOL arg5) {
  return ((ProtocolTrampoline_33)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4, arg5);
}

typedef id  (^ProtocolTrampoline_34)(void * sel, id arg1, struct _NSRange arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_19u921t(id target, void * sel, id arg1, struct _NSRange arg2, id arg3, id arg4) {
  return ((ProtocolTrampoline_34)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

typedef struct _NSRange  (^ProtocolTrampoline_35)(void * sel, id arg1, id arg2, id arg3, id * arg4);
__attribute__((visibility("default"))) __attribute__((used))
struct _NSRange  _FoundationBindings_protocolTrampoline_xsqx6i(id target, void * sel, id arg1, id arg2, id arg3, id * arg4) {
  return ((ProtocolTrampoline_35)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

typedef id  (^ProtocolTrampoline_36)(void * sel, id arg1, id arg2, unsigned long arg3, uint64_t arg4, id arg5, id arg6, long * arg7);
__attribute__((visibility("default"))) __attribute__((used))
id  _FoundationBindings_protocolTrampoline_1chy5b9(id target, void * sel, id arg1, id arg2, unsigned long arg3, uint64_t arg4, id arg5, id arg6, long * arg7) {
  return ((ProtocolTrampoline_36)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
}

typedef void  (^ListenerTrampoline_23)(void * arg0, id arg1, unsigned long arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_23 _FoundationBindings_wrapListenerBlock_1cn988u(ListenerTrampoline_23 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, unsigned long arg2, id arg3, id arg4, id arg5) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), arg2, (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4), (__bridge id)(__bridge_retained void*)(arg5));
  };
}

typedef void  (^BlockingTrampoline_23)(void * waiter, void * arg0, id arg1, unsigned long arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_23 _FoundationBindings_wrapBlockingBlock_1cn988u(
    BlockingTrampoline_23 block, BlockingTrampoline_23 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, unsigned long arg2, id arg3, id arg4, id arg5), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), arg2, (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4), (__bridge id)(__bridge_retained void*)(arg5));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), arg2, (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4), (__bridge id)(__bridge_retained void*)(arg5));
  });
}

typedef void  (^ProtocolTrampoline_37)(void * sel, id arg1, unsigned long arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
void  _FoundationBindings_protocolTrampoline_1cn988u(id target, void * sel, id arg1, unsigned long arg2, id arg3, id arg4, id arg5) {
  return ((ProtocolTrampoline_37)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4, arg5);
}

Protocol* _FoundationBindings_NSSpellServerDelegate(void) { return @protocol(NSSpellServerDelegate); }

Protocol* _FoundationBindings_NSUserNotificationCenterDelegate(void) { return @protocol(NSUserNotificationCenterDelegate); }
#undef BLOCKING_BLOCK_IMPL
