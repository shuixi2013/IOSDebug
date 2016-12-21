//
//  net.m
//  utility
//
//  Created by baidu on 2016/10/26.
//  Copyright © 2016年 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <ifaddrs.h>
#include <arpa/inet.h>

#include "common.h"

int net_getip(char* inbuf, char* outbuf)
{
    struct ifaddrs* interfaces = 0;
    struct ifaddrs* tmp_addr = 0;
    int success = getifaddrs(&interfaces);
    if(success == 0 && interfaces != 0)
    {
        success = 1;
        tmp_addr = interfaces;
        while(tmp_addr != 0)
        {
            if(tmp_addr->ifa_addr->sa_family == AF_INET)
            {
                if(!strcmp("en0", tmp_addr->ifa_name))
                {
                    char* addr = inet_ntoa(((struct sockaddr_in*)tmp_addr->ifa_addr)->sin_addr);
                    strncpy(outbuf, addr, BUFFER_SIZE);
                    success = 0;
                }
            }
            tmp_addr = tmp_addr->ifa_next;
        }
        freeifaddrs(interfaces);
    }
    return success;
}







