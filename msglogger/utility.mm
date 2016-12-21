
//
//
//  main.m
//  test
//
//  Created by baidu on 16/10/8.
//  Copyright © 2016年 baidu. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "utility.h"

#define ATTRIB_VISIBLE  __attribute__((visibility("default")))

using namespace std;

extern queue<string> msgqueue;
extern void init_filter();
void* (*ori_objc_msgSend)(id self, SEL selector, ...);


extern "C" ATTRIB_VISIBLE void print_ocobj(void* objaddr);
extern "C" ATTRIB_VISIBLE void print_msg_switch(int val);
extern "C" ATTRIB_VISIBLE void print_image();


/*******************************************打印对象print_ocobj**********************************************/
void print_ocobj_inner(void* objaddr, int layer);



const char* type_decode(const char* encoded)
{
    if(!strcmp(encoded, "b"))
        return "bitfield";
    if(!strcmp(encoded, "B"))
        return "bool";
    if(!strcmp(encoded, "c"))
        return "char";
    if(!strcmp(encoded, "C"))
        return "uchar";
    if(!strcmp(encoded, "d"))
        return "double";
    if(!strcmp(encoded, "f"))
        return "float";
    if(!strcmp(encoded, "i"))
        return "int";
    if(!strcmp(encoded, "I"))
        return "uint";
    if(!strcmp(encoded, "l"))
        return "long";
    if(!strcmp(encoded, "L"))
        return "Long";
    if(!strcmp(encoded, "q"))
        return "longlong";
    if(!strcmp(encoded, "Q"))
        return "ulonglong";
    if(!strcmp(encoded, "s"))
        return "short";
    if(!strcmp(encoded, "S"))
        return "ushort";
    if(!strcmp(encoded, "v"))
        return "void";
    if(!strcmp(encoded, "^"))
        return "void*";
    if(!strcmp(encoded, "@"))
        return "id";
    if(!strcmp(encoded, ":"))
        return "SEL";
    if(!strcmp(encoded, "*"))
        return "char*";
    if(!strcmp(encoded, "!"))
        return "vector";
    if(!strcmp(encoded, "?"))
        return "undefined";
    return encoded;
}

void print_ocobj_fortype(id objaddr, const char* encode, int layer)
{
    if(encode[0] == '@')
    {
        print_ocobj_inner((__bridge void*)objaddr, layer);
    }
}

void print_ocobj_inner(void* objaddr, int layer)
{
    const char* prearr[] = {"","\t","\t\t","\t\t\t","\t\t\t\t"};
    const char* prefix = prearr[layer];
    NSLog(@"%sdump for object %p", prefix, objaddr);
    id objectaddr = (__bridge id)objaddr;
    id curcls, supercls;
    
    char ch;
    if(objectaddr == 0)
    {
        return;
    }
    ch = ((char*)objaddr)[0];
    if( (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_')
    {
        curcls = objc_getClass((const char*)objaddr);
        if(curcls == 0)
        {
            NSLog(@"%snothing", prefix);
            return;
        }
        supercls = [curcls superclass];
    }
    else
    {
        curcls = [objectaddr class];
        supercls = [objectaddr superclass];
    }
    
    if(curcls == supercls || curcls == 0 || supercls == 0)
    {
        NSLog(@"%snothing", prefix);
        return;
    }
    
    //dump base info
    NSLog(@"%sClassName:%s ClassVersion:%d InstanceSize:%d IsClass:%d IsMetaClass:%d", prefix,
          class_getName(curcls),
          class_getVersion(curcls),
          (int)class_getInstanceSize(curcls),
          object_isClass(curcls),
          class_isMetaClass(curcls));
    NSLog(@"%sSuperClass:%s=%p belongto=%s", prefix,
          class_getName(supercls),
          supercls,
          class_getImageName(curcls));
    NSLog(@"%scontent=%@", prefix, objaddr);
    
    NSLog(@"\n");
    print_ocobj_inner((__bridge void*)supercls, layer + 1);
    NSLog(@"\n");
    
    //dump Ivars
    unsigned int IvarCount = 0;
    Ivar* IvarList = class_copyIvarList(curcls, &IvarCount);
    NSLog(@"%sIvars * %d", prefix, IvarCount);
    if(IvarCount != 0 && IvarList != 0)
    {
        for(int i = 0;i < IvarCount;i++)
        {
            const char* encode = ivar_getTypeEncoding(IvarList[i]);
            id val = object_getIvar(objectaddr, IvarList[i]);
            NSLog(@"%s\t+%08x \t%s \t%s \tval=%p", prefix,
                  (int)ivar_getOffset(IvarList[i]),
                  type_decode(encode),
                  ivar_getName(IvarList[i]),
                  val);
        }
        free(IvarList);
    }
    
    //dump Methods
    unsigned int MethodCount = 0;
    Method* MethodList = 0;
    MethodList = class_copyMethodList(curcls, &MethodCount);
    NSLog(@"%sMethods * %d", prefix, MethodCount);
    //non-static methods
    if(MethodCount != 0 && MethodList != 0)
    {
        for(int i = 0;i < MethodCount;i++)
        {
            char tmp[1024];
            unsigned int argnum = method_getNumberOfArguments(MethodList[i]);
            char* rettype = method_copyReturnType(MethodList[i]);
            SEL sel = method_getName(MethodList[i]);
            const char* name = sel?sel_getName(sel):"error";
            sprintf(tmp, "\t%s %s(", type_decode(rettype), name);
            if(rettype != 0)
                free(rettype);
            for(int j = 0;j < argnum;j++)
            {
                char* argtype = method_copyArgumentType(MethodList[i], j);
                sprintf(tmp, "%s%s,", tmp, argtype?type_decode(argtype):"");
                if(argtype != 0)
                    free(argtype);
            }
            unsigned long len = strlen(tmp);
            if(tmp[len - 1] == ',')
                tmp[len - 1] = 0;
            sprintf(tmp, "%s)=%p", tmp, method_getImplementation(MethodList[i]));
            NSLog(@"%s-%s", prefix, tmp);
        }
    }
    //static methods
    curcls = *(id*)curcls;
    MethodList = class_copyMethodList(curcls, &MethodCount);
    NSLog(@"%sMethods * %d", prefix, MethodCount);
    if(MethodCount != 0 && MethodList != 0)
    {
        for(int i = 0;i < MethodCount;i++)
        {
            char tmp[1024];
            unsigned int argnum = method_getNumberOfArguments(MethodList[i]);
            char* rettype = method_copyReturnType(MethodList[i]);
            SEL sel = method_getName(MethodList[i]);
            const char* name = sel?sel_getName(sel):"error";
            sprintf(tmp, "\t%s %s(", type_decode(rettype), name);
            if(rettype != 0)
                free(rettype);
            for(int j = 0;j < argnum;j++)
            {
                char* argtype = method_copyArgumentType(MethodList[i], j);
                sprintf(tmp, "%s%s,", tmp, argtype?type_decode(argtype):"");
                if(argtype != 0)
                    free(argtype);
            }
            unsigned long len = strlen(tmp);
            if(tmp[len - 1] == ',')
                tmp[len - 1] = 0;
            sprintf(tmp, "%s)=%p", tmp, method_getImplementation(MethodList[i]));
            NSLog(@"%s+%s", prefix, tmp);
        }
    }
    
    //dump Protocols
    unsigned int ProtocolCount = 0;
    __unsafe_unretained Protocol** ProtocolList = class_copyProtocolList(curcls, &ProtocolCount);
    NSLog(@"%sProtocols * %d", prefix, ProtocolCount);
    if(ProtocolCount != 0 && ProtocolList != 0)
    {
        for(int i = 0;i < ProtocolCount;i++)
        {
            const char* proname = protocol_getName(ProtocolList[i]);
            NSLog(@"%s\t%@ \t%s", prefix, ProtocolList[i], proname?proname:"null");
        }
    }
    
    //dump Propertys
    unsigned int PropertyCount = 0;
    NSLog(@"%sPropertys * %d", prefix, PropertyCount);
    objc_property_t* PropertyList = class_copyPropertyList(curcls, &PropertyCount);
    if(PropertyCount != 0 && PropertyList != 0)
    {
        for(int i = 0;i < PropertyCount;i++)
        {
            void* value = 0;
            const char* propname = property_getName(PropertyList[i]);
            const char* propattr = property_getAttributes(PropertyList[i]);
            object_getInstanceVariable(ProtocolList[i], propname, &value);
            NSLog(@"%s\t%s \t%s =%p", prefix, propname?propname:"null", propattr?propattr:"null", value);
        }
    }
}

extern "C" void print_ocobj(void* objaddr)
{
    print_ocobj_inner(objaddr, 0);
}


/**********************************************打印模块print_image******************************************/
extern "C" void print_image()
{
    void* handle = dlopen("libSystem.B.dylib", 1);
    void* _dyld_get_all_image_infos = dlsym(handle, "_dyld_get_all_image_infos");
    struct dyld_all_image_infos* allinfo = ((struct dyld_all_image_infos* (*)())_dyld_get_all_image_infos)();
    const struct dyld_image_info* info = allinfo->infoArray;
    for(int i = 0;i < allinfo->infoArrayCount;i++)
    {
        NSLog(@"\t%p\t%s", info[i].imageLoadAddress, info[i].imageFilePath);
    }
}

//function to replace objc_msgSend
__attribute__((__naked__))//there is no such grammar enable us pass parameter "..." to origin msgSend's "...", so we need it naked
static void* $objc_msgSend(id self, SEL selector, ...)
{
    __asm__ volatile (    
        //store current state
        "push {r0 - r11, lr}\n"
                      
        //first we need to preserve cursp for future use
        //remember we can't use R0 R1 R2 R3 as we used in our hook trick
        "mov r11, sp\n"
        "add r11, #0x34\n"//we push 13 registers
                      
        //do our hook trick
        "bl _intercept_msgSend\n"
        "mov r12, r0\n"
                      
        //recover the state stored before
        "pop {r0 - r11, lr}\n"
                      
        //invoke origin msg_send
        "bx r12"
  //                    ::"m"(saved_sp)
    );
 
}

void anti_anti_debug()
{
    //to do
}

void* (*olddlopen)(const char*, int);
void * mydlopen(const char * __path, int __mode)
{
    NSLog(@"----loaded %s----", __path);
    return olddlopen(__path, __mode);
}

MSInitialize
{
    void* handle = dlopen("libsubstrate.dylib",1);
    if(handle != 0)
    {
        init_filter();
        typedef void (*HOOK)(void*, void*, void**);
        HOOK MSHookFunctionX = (HOOK)dlsym(handle, "MSHookFunction");
        MSHookFunctionX((void*)objc_msgSend, (void*)&$objc_msgSend, (void**)&ori_objc_msgSend);
        MSHookFunctionX((void*)dlopen, (void*)mydlopen, (void**)&olddlopen);
    }
    
    anti_anti_debug();
    NSLog(@"------------------------libutility load ok------------------------");
}


//just for test
@interface MYCLS : NSObject
- (void) func1:(id)a1 title:(id)a2 title:(id)a3;
+ (void) func2:(id)a1 title:(id)a2 title:(id)a3;
@end
@implementation MYCLS
- (void) func1:(id)a1 title:(id)a2 title:(id)a3
{
    
}
+ (void) func2:(id)a1 title:(id)a2 title:(id)a3
{
    
}
@end
int main(int argc, char** argv)
{
    MYCLS* cls = [[MYCLS alloc] init];
    [cls func1:cls title:cls title:cls];

    printf("%p\n", *(id*)cls);
    int cursize = msgqueue.size();
    for(int i = 0;i < cursize;i++)
    {
        printf("%s\n", msgqueue.front().c_str());
        msgqueue.pop();
    }
}

