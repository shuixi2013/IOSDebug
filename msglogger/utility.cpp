//
//  utility.cpp
//  test
//
//  Created by baidu on 16/10/9.
//  Copyright © 2016年 baidu. All rights reserved.
//


//  /usr/lib//libutility.dylib

#include "utility.h"
#include <stdarg.h>

void* sel_min_addr = 0;
void* sel_max_addr = 0;

queue<string> msgqueue;
extern void* (*ori_objc_msgSend)(id self, SEL selector, ...);
FILE* logfile;
void init_filter()
{
    void* handle = dlopen("libSystem.B.dylib", 1);
    void* _dyld_get_all_image_infos = dlsym(handle, "_dyld_get_all_image_infos");
    struct dyld_all_image_infos* allinfo = ((struct dyld_all_image_infos* (*)())_dyld_get_all_image_infos)();
    const struct dyld_image_info* info = allinfo->infoArray;
    logfile=fopen("/tmp/msglog.txt","wb");
    for(int i = 0;i < allinfo->infoArrayCount;i++)
    {
        if(strstr(info[i].imageFilePath, ".app"))
        {
            sel_min_addr = (void*)info[i].imageLoadAddress;
            sel_max_addr = (void*)info[i + 1].imageLoadAddress;
            break;
        }
    }
    
}

char buffer[256];
char buffer2[256];

static const char* map314[] = {
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,	// 0 - F
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,	// 10 - 1F
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    
    NULL, "/*gc-invisible*/", NULL, "Class", NULL, "NXAtom", NULL, NULL,	// 20 - 2F
    NULL, NULL, "char*", NULL, NULL, NULL, NULL, NULL,
    
    NULL, NULL, NULL, NULL, "/*function*/", "?", "/*xxintrnl-category*/", "/*xxintrnl-protocol*/",	// 30 - 3F
    NULL, NULL, "SEL", NULL, NULL, NULL, NULL, "/*function-pointer*/ void",
    
    "id", NULL, "bool", "unsigned char", NULL, NULL, NULL, NULL,	// 40 - 4F
    NULL, "unsigned", NULL, NULL, "unsigned long", NULL, "inout", "bycopy",
    
    NULL, "unsigned long long", "byref", "unsigned short", NULL, NULL, "oneway",	// 50 - 5F
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    
    NULL, NULL, NULL, "char", "double", NULL, "float", NULL, 	// 60 - 6F
    NULL, "int", "_Complex", NULL, "long", NULL, "in", "out",
    
    NULL, "long long", "const", "short", NULL, NULL, "void",	// 70 - 7F
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,// 80 - 8F
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,// 90 - 9F
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,// A0 - AF
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,// B0 - BF
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,// C0 - CF
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,// D0 - DF
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,// E0 - EF
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,// F0 - FF
    
};

//定义必须放到.c|.cpp中防止编译器产生调用objc_msgSend的代码导致递归
extern "C" void* intercept_msgSend(id self, SEL selector, ...)
{
    //最外层不要有耗时操作
    if((void*)selector > sel_min_addr && (void*)selector < sel_max_addr)
    {
        const char* name = object_getClassName(self);

//#define DETAIL
#ifndef DETAIL //if we donot want output parameter info
        {
            snprintf(buffer, 256, "[%s %s]\n", name, (char*)selector);
        }
#else
        /*
         Class curcls = object_getClass(self);
         Method method;
         bool isstatic = false;
         
        method = class_getInstanceMethod(curcls, selector);
        if(class_isMetaClass(curcls))
        {//static method function call -> [metaclass selector];
            isstatic = true;
        }
        else
        {
            isstatic = false;
        }

        if(method != 0)
        {
            char typedescri[50];
            int argnum = (char)method_getNumberOfArguments(method);
            method_getReturnType(method, typedescri, 50);
            const char* rettype = map314[*typedescri];

            if(!rettype)
            {
                rettype = typedescri;
            }
            if(*typedescri == '@')
            {
                rettype = object_getClassName(self);
            }
            snprintf(buffer, 256, "%c[%s %s] %s(*)(", isstatic?'+':'-', object_getClassName(self), (const char*)selector, rettype);
            
            //the real parameter(without id and selector for member function) is stored in R2 R3 [SP+0] [SP+4] [SP+8]...
            //while stdarg functions can only deal with the first two, so we need to preserve [SP+0] [SP+4] first in out hook trick
            
            
            unsigned long* saved_sp;
            __asm__(
                    "str r11, %0\n"::"m"(saved_sp) //here we got pointers to param3 ,param4, ...
                    );
            
            va_list ap;
            va_start(ap, selector);
            unsigned long saved_params[20];
            
            //first two params we can get from stdarg
            saved_params[2] = va_arg(ap, unsigned long);
            saved_params[3] = va_arg(ap, unsigned long);
            for(int j = 4;j < argnum;j++)
            {
                saved_params[j] = saved_sp[j - 4];
            }

            for(int j = 2;j < argnum;j++)
            {
                method_getArgumentType(method, j, typedescri, 50);
                const char* argtype = map314[*typedescri];
                
                //get n'th parameter
                if(*typedescri == '@')
                {
                    if(sel_min_addr <= (void*)saved_params[j] && (void*)saved_params[j] <= sel_max_addr)
                        //不做此限制会崩溃
                        argtype = object_getClassName((id)saved_params[j]);
                }
                if(!argtype)
                {
                    argtype = typedescri;
                }
                if(*typedescri == 'Q' || *typedescri == 'q' || *typedescri == 'd')
                {
                    //not handle yet     possess 2 int

                }
                
                snprintf(buffer2, 256, "%s=0x%x,", argtype, saved_params[j]);
                strncat(buffer, buffer2, 256);
            }
            strncat(buffer, ")\n", 256);
        }
         */
#endif
         
        fwrite(buffer ,strlen(buffer),1,logfile);
       // msgqueue.push(buffer);
    }
    return (void*)ori_objc_msgSend;
}

