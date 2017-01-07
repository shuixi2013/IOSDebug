//
//  utility.h
//  utility
//
//  Created by baidu on 16/10/10.
//  Copyright © 2016年 baidu. All rights reserved.
//

#ifndef utility_h
#define utility_h

#include <netinet/in.h>    // for sockaddr_in
#include <sys/types.h>    // for socket
#include <sys/socket.h>    // for socket
#include <arpa/inet.h>
#include <sys/types.h>    // for socket
#include <objc/runtime.h>
#include <string>
#include <queue>
#include <vector>
#include <map>
using namespace std;

#include <dlfcn.h>
#include "substrate.h"
#include <string.h>

typedef unsigned int uint32_t;
typedef unsigned long uintptr_t;

struct dyld_image_info
{
    const void* imageLoadAddress;
    const char* imageFilePath;
    uintptr_t imageFileModDate;
};

struct dyld_all_image_infos
{
    uint32_t version;
    uint32_t infoArrayCount;
    const struct dyld_image_info* infoArray;
};

#endif /* utility_h */
