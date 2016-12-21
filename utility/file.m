//
//  file.m
//  utility
//
//  Created by baidu on 2016/10/27.
//  Copyright © 2016年 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

#define MH_MAGIC 0xfeedface
#define MH_CIGAM 0xcefaedfe
#define MH_MAGIC_64 0xfeedfacf
#define MH_CIGAM_64 0xcffaedfe
#define FAT_MAGIC 0xcafebabe
#define FAT_CIGAM 0xbebafeca

typedef struct _fat_arch
{
    unsigned int cpu_type;
    unsigned int cpu_sub_type;
    unsigned int file_offset;
    unsigned int size;
    unsigned int align;
} fat_arch;

typedef struct _mach_header
{
    unsigned int magic;
    unsigned int cputype;
    unsigned int cpusubtype;
    unsigned int filetype;
    unsigned int ncmds;
    unsigned int sizeofcmds;
    unsigned int flags;
//   int reserved;
} mach_header;

typedef struct _load_command
{
    unsigned int cmd;
    unsigned int cmdsize;
} load_command;

typedef struct _dylib_command
{
    unsigned int cmd;
    unsigned int cmdsize;
    unsigned int nameoff;
    unsigned int timestamp;
    unsigned int current_version;
    unsigned int compatibility_version;
    char name[256];
} dylib_command;

unsigned int reverse_dword(unsigned int input)
{
    return ((input&0xff)<<24) || (((input>>8)&0xff)<<16) || (((input>>16)&0xff)<<8) || ((input>>24)&0xff);
}

void fix_onepart(FILE* fp, int offset, char* injlibpath)
{
#define MH_PIE              0x200000
#define LC_SEGMENT          0x1
#define LC_SEGMENT_64       0x19
#define LC_LOAD_WEAK_DYLIB  0x80000018
    fseek(fp, offset, SEEK_SET);
    struct _mach_header header;
    int reserved;
    bool reverse = false;
    bool is64 = false;
    fread(&header, sizeof(header), 1, fp);
    
    if(header.magic == MH_MAGIC_64 || header.magic == MH_CIGAM_64)
    {
        fread(&reserved, 4, 1, fp);
        is64 = true;
    }
    if(header.magic == MH_CIGAM || header.magic == MH_CIGAM_64)
    {
        printf("cannot handle yet, big endian\n");
        return;
    }
    printf("image ok\n");
    int curoff = sizeof(header);
    for(int i = 0;i < header.ncmds;i++)
    {
        struct _load_command ldcmd;
        fread(&ldcmd, sizeof(load_command), 1, fp);
        if(ldcmd.cmd == LC_SEGMENT || ldcmd.cmd == LC_SEGMENT_64)
        {
            char segname[16];
            char segmatch[16] = "__RESTRICT";
            fread(segname, 16, 1, fp);
            if(!strncmp(segname, segmatch, 10))
            {
                segmatch[2] = 'X';
                fseek(fp, curoff + sizeof(load_command), SEEK_SET);
                fwrite(segmatch, 16, 1, fp);
            }
        }
        curoff += ldcmd.cmdsize;
        fseek(fp, curoff, SEEK_SET);
    }
    //here is the end of commands, so we add command here
    if(injlibpath != 0)
    {
        bool haslib = true;
        do
        {
            struct _dylib_command dc;
            int pathlen = 0;
            if(strchr(injlibpath, '+') != 0)
            {
                pathlen = strchr(injlibpath, '+') - injlibpath;
            }
            else
            {
                pathlen = strlen(injlibpath);
                haslib = false;
            }
            int alignlen = ((pathlen+3)/4)*4;
            dc.cmd = LC_LOAD_WEAK_DYLIB;
            dc.cmdsize = 24 + alignlen;
            dc.nameoff = 24;
            dc.timestamp = 2;
            dc.current_version = 0;
            dc.compatibility_version = 0;
            memset(dc.name, 0, 256);
            memcpy(dc.name, injlibpath, pathlen);
            fwrite(&dc, dc.cmdsize, 1, fp);
            header.ncmds++;
            header.sizeofcmds += dc.cmdsize;
            injlibpath += pathlen + 1;
        } while(haslib);
    }
    header.flags &= ~MH_PIE;//we modify here
    fseek(fp, offset, SEEK_SET);
    fwrite(&header, sizeof(header), 1, fp);
}

int file_fixup(char* inbuf, char* outbuf)
{
    char* srcfilepath = inbuf;
    char* injectlibpath = strchr(srcfilepath, '+');
    if(injectlibpath != 0)
    {
        *injectlibpath++ = 0;
    }

    if( 0 != access(srcfilepath, 0))
    {
        printf("src file non exist\n");
        return -1;
    }
    else
    {
        printf("src file ok\n");
    }
    
    //make a backup
    char* command[256];
    snprintf(command, 256, "cp %s %s_bak", srcfilepath, srcfilepath);
    system(command);
    
//    if( injectlibpath != 0 && access(injectlibpath, 0) != 0)
//    {
//        printf("inject file non exist");
//        return -2;
//    }
    FILE* fp = fopen(srcfilepath, "rb+");
    if(fp == 0)
    {
        printf("open failed\n");
        return -3;
    }
    else
    {
        printf("open ok\n");
    }
    //检查mach-o格式
    unsigned int magic = 0;
    fread(&magic, 4, 1, fp);
    if(magic == MH_MAGIC || magic == MH_CIGAM || magic == MH_MAGIC_64 || magic == MH_CIGAM_64)
        fix_onepart(fp, 0, injectlibpath);
    else if(magic == FAT_MAGIC || magic == FAT_CIGAM)
    {
        int archnum = 0;
        fread(&archnum, 4, 1, fp);
        if(magic == FAT_CIGAM)
            archnum = reverse_dword(archnum);
        for(int i = 0;i < archnum;i++)
        {
            struct _fat_arch ar;
            fread(&ar, sizeof(fat_arch), 1, fp);
            if(magic == FAT_CIGAM)
            {
                ar.file_offset = reverse_dword(ar.file_offset);
            }
            fix_onepart(fp, ar.file_offset, injectlibpath);
        }
    }
    else
    {
        printf("magic error %x", magic);
        return -4;
    }
    fclose(fp);
    
    return 0;
}
