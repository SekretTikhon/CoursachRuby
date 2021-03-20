#define _GNU_SOURCE     1
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <err.h>

int main(void){
    const char socket_path[] = "#code-generator-socket";
    const int on = 1;
    struct sockaddr_un addr;
    int sock, n;
    size_t size;

    //create socket
    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) err(1, "socket create");
    
    //set SO_PASSCRED option
    if(setsockopt(sock, SOL_SOCKET, SO_PASSCRED, &on, sizeof on)) err(1, "setsockopt");

    //init sockaddr_un addr
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, socket_path);
    size = (offsetof(struct sockaddr_un, sun_path) + strlen(addr.sun_path));
    addr.sun_path[0] = 0;

    //connect to socket
    if (connect(sock, &addr, size) < 0 ) err(1, "connect");

    //recv data
    char buffer[256];
    bzero(buffer, 256);
    if (read(sock, buffer, 255) < 0) err(1, "read to buffer");

    //parse data
    char *url, *code, *delimiter = strchr(buffer, '\n');
    int url_length = delimiter - buffer;
    int code_length = strlen(delimiter + 1);
    url = malloc(url_length + 1);
    code = malloc(code_length + 1);
    memcpy(url, buffer, url_length);
    memcpy(code, delimiter + 1, code_length);

    printf("Your code: %s\nUse it when you login.\nOr follow this link: %s/login?code=%s\n", code, url, code);
    return 0;
}