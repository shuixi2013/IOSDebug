//
//  listapp.m
//  utility
//
//  Created by baidu on 2016/10/24.
//  Copyright © 2016年 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <dirent.h>
#include <sys/stat.h>
#include <string.h>
#include "common.h"


#include "plist/plist.h"


void resolveplist(char* buf/*file*/, int filesize, char* appid, char* outbuf, bool isuser)
{
    plist_t root_node = 0;
    plist_from_memory(buf, filesize, &root_node);
    if(root_node)
    {
        plist_t node_CFBundleDisplayName = plist_dict_get_item(root_node, "CFBundleDisplayName");
        plist_t node_CFBundleName = plist_dict_get_item(root_node, "CFBundleName");
        plist_t node_MinimumOSVersion = plist_dict_get_item(root_node, "MinimumOSVersion");
        plist_t node_CFBundleIdentifier = plist_dict_get_item(root_node, "CFBundleIdentifier");
        plist_t node_CFBundleExecutable = plist_dict_get_item(root_node, "CFBundleExecutable");
        plist_t node_CFBundleURLTypes = plist_dict_get_item(root_node, "CFBundleURLTypes");
        char* str_CFBundleDisplayName = "";
        char* str_CFBundleName = "";
        char* str_MinimumOSVersion = "";
        char* str_CFBundleIdentifier = "";
        char* str_CFBundleExecutable = "";
        char str_CFBundleURLTypes[256];
        if(node_CFBundleDisplayName != 0)
            plist_get_string_val(node_CFBundleDisplayName, &str_CFBundleDisplayName);
        if(node_CFBundleName != 0)
            plist_get_string_val(node_CFBundleName, &str_CFBundleName);
        if(node_MinimumOSVersion != 0)
            plist_get_string_val(node_MinimumOSVersion, &str_MinimumOSVersion);
        if(node_CFBundleIdentifier != 0)
            plist_get_string_val(node_CFBundleIdentifier, &str_CFBundleIdentifier);
        if(node_CFBundleExecutable != 0)
            plist_get_string_val(node_CFBundleExecutable, &str_CFBundleExecutable);
        if(node_CFBundleURLTypes != 0)
        {
            int size = plist_array_get_size(node_CFBundleURLTypes);
            char tmpt[256] = "";
            for(int i = 0;i < size;i++)
            {
                char* strt = "";
                plist_t item = plist_array_get_item(node_CFBundleURLTypes, i);
                if(item != 0)
                {
                    plist_t itemi = plist_dict_get_item(item, "CFBundleURLSchemes");
                    if(itemi != 0)
                    {
                        int lsize = plist_array_get_size(itemi);
                        for(int j = 0;j < lsize ;j++)
                        {
                            plist_t itemj = plist_array_get_item(itemi, j);
                            plist_get_string_val(itemj, &strt);
                            strncat(tmpt, strt, 256);
                            strncat(tmpt, "|", 256);
                        }
                    }
                }
            }
            strncpy(str_CFBundleURLTypes, tmpt, 256);
        }
        snprintf(outbuf, BUFFER_SIZE, "%sType=%s,AppId=%s,CFBundleDisplayName=%s,CFBundleName=%s,MinimumOSVersion=%s,CFBundleIdentifier=%s,"
                 "CFBundleExecutable=%s,CFBundleURLTypes=%s\n", outbuf, isuser?"User":"System", appid, str_CFBundleDisplayName, str_CFBundleName,
                 str_MinimumOSVersion, str_CFBundleIdentifier, str_CFBundleExecutable, str_CFBundleURLTypes);
    }
}

//CFBundleDisplayName|CFBundleName|MinimumOSVersion|CFBundleIdentifier|CFBundleExecutable|CFBundleURLTypes

int app_list(char* inbuf, char* outbuf)
{
    //枚举用户store中的app
    const char* root = "/var/mobile/Applications";
    const char* tmp[256];
    DIR* dh;
    struct dirent* entry;
    struct stat statbuf;
    if((dh = opendir(root)) == 0)
    {
        return 1;
    }
    while((entry = readdir(dh)) != 0)
    {
        //first we find dirname=appid
        if(!strcmp(".", entry->d_name) || !strcmp("..", entry->d_name))
            continue;
        //then we find dir name end with .app
        DIR* subdh;
        struct dirent* subentry = 0;
        snprintf(tmp, 256, "%s/%s", root, entry->d_name);
        if((subdh = opendir(tmp)) != 0)
        {
            while((subentry = readdir(subdh)) != 0)
            {
                if(strstr(subentry->d_name, ".app") != 0)
                {
                    break;
                }
            }
            closedir(subdh);
        }
        if(subentry)
        {
            snprintf(tmp, 256, "%s/%s/%s/%s", root, entry->d_name, subentry->d_name, "Info.plist");
            if(access(tmp, F_OK) == 0)
            {
                //解析plist
                FILE* plistfile = fopen(tmp, "rb");
                if(plistfile != 0)
                {
                    fseek(plistfile, 0, SEEK_END);
                    unsigned long filesize = ftell(plistfile);
                    fseek(plistfile, 0 ,SEEK_SET);
                    char* buf = (char*)malloc(filesize);
                    fread(buf, filesize, 1, plistfile);
                    fclose(plistfile);
                    resolveplist(buf, filesize, entry->d_name, outbuf, true);
                    free(buf);
                }
            }
        }
    }
    closedir(dh);
    
    root = "/Applications";
    if((dh = opendir(root)) == 0)
    {
        return 1;
    }
    while((entry = readdir(dh)) != 0)
    {
        //first we find dirname=appid
        if(0 == strstr(entry->d_name, ".app"))
            continue;
        //then we find dir name end with .app
        snprintf(tmp, 256, "%s/%s/%s", root, entry->d_name, "Info.plist");
        if(access(tmp, F_OK) == 0)
        {
            //解析plist
            FILE* plistfile = fopen(tmp, "rb");
            if(plistfile != 0)
            {
                fseek(plistfile, 0, SEEK_END);
                unsigned long filesize = ftell(plistfile);
                fseek(plistfile, 0 ,SEEK_SET);
                char* buf = (char*)malloc(filesize);
                fread(buf, filesize, 1, plistfile);
                fclose(plistfile);
                resolveplist(buf, filesize, "", outbuf, false);
                free(buf);
            }
        }
    }
    closedir(dh);

    
    return 0;
}

int app_open(char* inbuf, char* outbuf)
{
    char buf[256];
    snprintf(buf,256,"open %s", inbuf);
    system(buf);
    return 0;
}

int app_inject(char* inbuf, char* outbuf)
{
    char* bundleid = inbuf;
    FILE* file = fopen("/Library/MobileSubstrate/DynamicLibraries/libmsglogger.plist", "wb");
    // /Library/MobileSubstrate/DynamicLibraries/libutility.dylib需要存在
    if(file != 0)
    {
        char buf[1024];
        memset(buf, 0, 1024);
        snprintf(buf, 1024,
                 "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                 "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
                 "<plist version=\"1.0\">\n"
                 "<dict>\n"
                 "\t<key>Filter</key>\n"
                 "\t<dict>\n"
                 "\t\t<key>Bundles</key>\n"
                 "\t\t<array>\n"
                 "\t\t\t<string>%s</string>\n"
                 "\t\t</array>\n"
                 "\t</dict>\n"
                 "</dict>\n"
                 "</plist>\n"
                 , bundleid);
        fwrite(buf, 1024, 1, file);
        fclose(file);
        snprintf(buf,256,"open %s", inbuf);
        //使用24000端口通信
        system(buf);
    }
    //write into
    return 0;
}


