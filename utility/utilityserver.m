//
//  main.m
//  utilityserver
//
//  Created by baidu on 2016/10/24.
//  Copyright © 2016年 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Quartzcore/Quartzcore.h>
#import <UIKit/UIKit.h>
#include <netinet/in.h>    // for sockaddr_in
#include <sys/types.h>    // for socket
#include <sys/socket.h>    // for socket
#include <arpa/inet.h>
#include <stdio.h>        // for printf
#include <stdlib.h>        // for exit
#include <string.h>        // for bzero
#include "common.h"

#define LENGTH_OF_LISTEN_QUEUE 20
#define DEFAULT_PORT 23000//our default port


extern int app_list(char* inbuf, char* outbuf);
extern int app_open(char* inbuf, char* outbuf);
extern int app_inject(char* inbuf, char* outbuf);
extern int process_list(char* inbuf, char* outbuf);

extern int net_getip(char* inbuf, char* outbuf);
extern int net_setproxy(char* inbuf, char* outbuf);
extern int file_fixup(char* inbuf, char* outbuf);

int handleCommand(char* incmd, char* inbuf, char* outcmd, char* outbuf)
{
    int ret = 0xffff;
    /****************************  进程操作  ********************************/
    if(!strncmp(incmd, "process_list", sizeof("process_list") - 1))
    {//枚举进程
        ret = process_list(inbuf, outbuf);
    }
    //else if(!strncmp(incmd, "process_cmd", sizeof("process_cmd") - 1))
    //{
    //dumo_classes dump_object search_object_for_type log_ocfunc log_cfunc log_module_ocfunc
    //log_NSLog get_module_for_class
    //include parameter type)
    //}

    /****************************  应用操作  ********************************/
    else if(!strncmp(incmd, "app_list", sizeof("app_list") - 1))
    {//枚举app(CFBundleDisplayName|CFBundleName|MinimumOSVersion|CFBundleIdentifier|CFBundleExecutable)
        ret = app_list(inbuf, outbuf);
    }
    else if (!strncmp(incmd, "app_open", sizeof("process_open") - 1))
    {//创建app进程
        ret = app_open(inbuf, outbuf);
    }
    else if(!strncmp(incmd, "app_inject", sizeof("app_inject") - 1))
    {//使用cydia DYLD_INSERT_LIBRARY方式注入utility.dylib，拉起后返回通信socket
        ret = app_inject(inbuf, outbuf);
        app_open(inbuf, inbuf);//拉起
    }
    
    /****************************  文件操作  ********************************/
    else if(!strncmp(incmd, "file_fixup", sizeof("file_fixup") - 1))
    {//app打补丁，包括反反调试，反反注入，注入等
        
    }
    
    /****************************  网络操作  ********************************/
    else if(!strncmp(incmd, "net_getip", sizeof("net_getip") - 1))
    {//获取ip地址
        ret = net_getip(inbuf, outbuf);
    }

    /****************************  设备操作  ********************************/
    else if(!strncmp(incmd, "device_restart_springboard", sizeof("device_restart_springboard") - 1))
    {//重启sprintboard
        system("killall -9 SpringBoard");
    }
    else if(!strncmp(incmd, "device_clearlog", sizeof("log") - 1))
    {//日志清除
        system("echo > /var/log/syslog");
    }
    if(ret == 0)
        strncmp(outcmd, "SUCCESS", COMMAND_SIZE);
    else
        strncmp(outcmd, "FAILED", COMMAND_SIZE);
    return ret;
}

void initserver(unsigned short port)
{
    struct sockaddr_in server_addr;
    bzero(&server_addr,sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htons(INADDR_ANY);
    server_addr.sin_port = htons(port);
    
    int server_socket = socket(PF_INET,SOCK_STREAM,0);
    if( server_socket < 0)
    {
        printf("Create Socket Failed!");
        exit(1);
    }
    int opt =1;
    setsockopt(server_socket,SOL_SOCKET,SO_REUSEADDR,&opt,sizeof(opt));
    if( bind(server_socket,(struct sockaddr*)&server_addr,sizeof(server_addr)))
    {
        printf("Server Bind Port : %d Failed!", port);
        exit(1);
    }
    if ( listen(server_socket, LENGTH_OF_LISTEN_QUEUE) )
    {
        printf("Server Listen Failed!");
        exit(1);
    }
    
    printf("listening on port %d:\n", port);
    struct sockaddr_in client_addr;
    socklen_t length = sizeof(client_addr);
    int new_server_socket = accept(server_socket,(struct sockaddr*)&client_addr,&length);
    if ( new_server_socket < 0)
    {
        printf("Server Accept Failed!\n");
        exit(0);
    }
    printf("%s:%d connected\n", inet_ntoa(client_addr.sin_addr), client_addr.sin_port);
    
    while (1)
    {
        const int TOTALSIZE = BUFFER_SIZE + COMMAND_SIZE;
        char inbuffer[TOTALSIZE], outbuffer[TOTALSIZE];
        bzero(inbuffer, TOTALSIZE);
        bzero(outbuffer, TOTALSIZE);
        int buflen = recv(new_server_socket, inbuffer, TOTALSIZE, 0);
        if (buflen < 0)
        {
            printf("Server Recieve Data Failed!\n");
            break;
        }
        handleCommand(inbuffer, inbuffer + COMMAND_SIZE, outbuffer, outbuffer + COMMAND_SIZE);
        send(new_server_socket, outbuffer, TOTALSIZE, 0);
    }
    close(new_server_socket);
    close(server_socket);
}

extern int net_getip(char* inbuf, char* outbuf);
const int TOTALSIZE = BUFFER_SIZE + COMMAND_SIZE;

int main(int argc, char **argv)
{
    //handle arguments
    if(argc == 1)
    {
        //show help
        printf("--app_list\n"
               "--process_list\n"
               "--net_getip\n"
               "--app_inject <appbundle>\n"
               "--file_fixup </path/to/file/>[+/path/to/dylib1][+/path/to/dylib2]...\n");
        return 0;
    }
    
    //文件操作暂时支持arm
    
    for(int i=1;i<argc;i++)
    {
        if(!strncmp(argv[i], "--app_list", sizeof("--app_list") - 1))//获取app列表
        {
            char buf[TOTALSIZE];
            app_list(buf, buf);
            puts(buf);
        }
        if(!strncmp(argv[i], "--process_list", sizeof("--process_list") - 1))//获取进程列表
        {
            char buf[TOTALSIZE];
            process_list(buf, buf);
            puts(buf);
        }
        if(!strncmp(argv[i], "--net_getip", sizeof("--net_getip") - 1))//获取当前ip
        {
            char buf[TOTALSIZE];
            net_getip(buf, buf);
            puts(buf);
        }
        if(!strncmp(argv[i], "--app_inject", sizeof("--app_inject") - 1))//增加cydia注入项libmsglogger，注入到bundleid指定进程
        {
            char buf[TOTALSIZE];
            ++i;
            strncpy(buf, argv[i], strlen(argv[i]));
            app_inject(buf, buf);
        }
        if(!strncmp(argv[i], "--file_fixup", sizeof("--file_fixup") - 1))//移除模块地址随机化 移除反注入 增加注入项
        {
            char buf[TOTALSIZE];
            ++i;
            strncpy(buf, argv[i], strlen(argv[i]));
            file_fixup(buf, buf);
        }
    }
    return 0;
}


