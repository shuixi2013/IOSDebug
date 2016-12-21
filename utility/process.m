//
//  process_list.m
//  utility
//
//  Created by baidu on 2016/10/26.
//  Copyright © 2016年 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/sysctl.h>
#include "plist/plist.h"
#include "common.h"

int process_list(char* inbuf, char* outbuf)
{
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t miblen = 4;
    size_t size;
    int st = sysctl(mib, miblen, 0, &size, 0, 0);
    struct kinfo_proc* process = 0;
    struct kinfo_proc* newprocess = 0;
    do
    {
        size += size / 10;
        newprocess = realloc(process, size);
        if(!newprocess)
        {
            if(process)
            {
                free(process);
            }
            return nil;
        }
        process = newprocess;
        st = sysctl(mib, miblen, process, &size, 0, 0);
    }
    while(st == -1 && errno == ENOMEM);
    if(st == 0)
    {
        if(size % sizeof(struct kinfo_proc) == 0)
        {
            int nprocess = size / sizeof(struct kinfo_proc);
            for(int i = 0;i < nprocess;i++)
            {
                snprintf(outbuf, BUFFER_SIZE, "%spid=%d,ppid=%d,name=%s\n", outbuf, process[i].kp_proc.p_pid,
                         process[i].kp_eproc.e_ppid, process[i].kp_proc.p_comm);
            }
            return 0;
        }
    }
    return 1;
}


