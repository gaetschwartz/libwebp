#include <stdint.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <CoreImage/CoreImage.h>

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


typedef id  (^ProtocolTrampoline)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
id  _CoreImageBindings_protocolTrampoline_1mbt9g9(id target, void * sel) {
  return ((ProtocolTrampoline)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef BOOL  (^ProtocolTrampoline_1)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _CoreImageBindings_protocolTrampoline_e3qsqz(id target, void * sel) {
  return ((ProtocolTrampoline_1)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^ListenerTrampoline)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline _CoreImageBindings_wrapListenerBlock_18v1jvf(ListenerTrampoline block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^BlockingTrampoline)(void * waiter, void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline _CoreImageBindings_wrapBlockingBlock_18v1jvf(
    BlockingTrampoline block, BlockingTrampoline listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  });
}

typedef void  (^ProtocolTrampoline_2)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _CoreImageBindings_protocolTrampoline_18v1jvf(id target, void * sel, id arg1) {
  return ((ProtocolTrampoline_2)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef id  (^ProtocolTrampoline_3)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
id  _CoreImageBindings_protocolTrampoline_xr62hr(id target, void * sel, id arg1) {
  return ((ProtocolTrampoline_3)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

Protocol* _CoreImageBindings_MTLTexture(void) { return @protocol(MTLTexture); }

Protocol* _CoreImageBindings_CIFilterConstructor(void) { return @protocol(CIFilterConstructor); }

Protocol* _CoreImageBindings_MTLCommandBuffer(void) { return @protocol(MTLCommandBuffer); }

Protocol* _CoreImageBindings_MTLDevice(void) { return @protocol(MTLDevice); }

Protocol* _CoreImageBindings_MTLCommandQueue(void) { return @protocol(MTLCommandQueue); }

Protocol* _CoreImageBindings_CIFilter(void) { return @protocol(CIFilter); }

typedef struct CGRect  (^ProtocolTrampoline_4)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
struct CGRect  _CoreImageBindings_protocolTrampoline_1c3uc0w(id target, void * sel) {
  return ((ProtocolTrampoline_4)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef size_t  (^ProtocolTrampoline_5)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
size_t  _CoreImageBindings_protocolTrampoline_150qdkd(id target, void * sel) {
  return ((ProtocolTrampoline_5)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef int  (^ProtocolTrampoline_6)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
int  _CoreImageBindings_protocolTrampoline_1l0nlq(id target, void * sel) {
  return ((ProtocolTrampoline_6)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void *  (^ProtocolTrampoline_7)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
void *  _CoreImageBindings_protocolTrampoline_3fl8pv(id target, void * sel) {
  return ((ProtocolTrampoline_7)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef struct __IOSurface *  (^ProtocolTrampoline_8)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
struct __IOSurface *  _CoreImageBindings_protocolTrampoline_tg5r79(id target, void * sel) {
  return ((ProtocolTrampoline_8)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef struct __CVBuffer *  (^ProtocolTrampoline_9)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
struct __CVBuffer *  _CoreImageBindings_protocolTrampoline_vfhx8p(id target, void * sel) {
  return ((ProtocolTrampoline_9)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef uint64_t  (^ProtocolTrampoline_10)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
uint64_t  _CoreImageBindings_protocolTrampoline_k3xjiw(id target, void * sel) {
  return ((ProtocolTrampoline_10)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef unsigned long  (^ProtocolTrampoline_11)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
unsigned long  _CoreImageBindings_protocolTrampoline_1ckyi24(id target, void * sel) {
  return ((ProtocolTrampoline_11)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

Protocol* _CoreImageBindings_CIImageProcessorInput(void) { return @protocol(CIImageProcessorInput); }

Protocol* _CoreImageBindings_CIImageProcessorOutput(void) { return @protocol(CIImageProcessorOutput); }
#undef BLOCKING_BLOCK_IMPL
