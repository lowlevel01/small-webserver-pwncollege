.intel_syntax noprefix
.globl _start





.section .bss
socket_fd:
    .space 8 # socket file descriptor
client_fd:
    .space 8 # client file descriptor
file_fd:
    .space 8 # file file descriptor
file_size:
    .space 8  # to register file size
.section .text

_start:
    # Create socket
    mov rdi, 2                # AF_INET
    mov rsi, 1                # SOCK_STREAM
    xor rdx, rdx              # Protocol (0 for IP)
    mov rax, 41               # SYS_socket
    syscall

    # Check if socket creation was successful
    test rax, rax
    js exit                   # Exit if syscall failed

    # Save socket file descriptor
    mov [socket_fd], rax

    # Bind socket
    lea rsi, [sockaddr_in] # Load address of sockaddr_in
    mov rdi, [socket_fd]
    mov rdx, 16               # Length of sockaddr_in
    mov rax, 49               # SYS_bind
    syscall

    # Check if bind was successful
    test rax, rax
    js exit                   # Exit if syscall failed

    # Listen on socket
    xor rsi, rsi              # Max backlog = 0
    mov rax, 50               # SYS_listen
    syscall

    # Check if listen was successful
    test rax, rax
    js exit                   # Exit if syscall failed

    # Accept connection
    xor rsi, rsi              # addr parameter (NULL)
    xor rdx, rdx              # addrlen parameter (0)
    mov rax, 43               # SYS_accept
    syscall

    # Check if accept was successful
    test rax, rax
    js exit                   # Exit if syscall failed

    # Save client socket file descriptor
    mov [client_fd], rax

    # Read request
    lea rsi, [request_buffer] # Request buffer
    mov rdi, [client_fd]
    mov rdx, 1024             # Buffer size
    mov rax, 0                # SYS_read
    syscall


# Null-terminate the path
    lea rdi, [request_buffer]     # Load the address of request_buffer
    add rdi, 4                    # Move past "GET "
    mov rcx, 0

find_space:
    cmp byte ptr [rdi + rcx], ' '  # Check for space
    je null_terminate                # Jump to null termination if space is found
    cmp byte ptr [rdi + rcx], 0      # Check for null terminator
    je null_terminate                 # Handle end of string
    inc rcx
    jmp find_space

null_terminate:
    mov byte ptr [rdi + rcx], 0x00   # Null-terminate the string


#after null terminating
    # Open file
    lea rdi, [request_buffer+4] # File path after "GET /"
    mov rsi, 0                # Flags for read-only
    mov rdx, 0
    mov rax, 2                # SYS_open
    syscall

    # Check if open was successful
    test rax, rax
    js send_response          # If open fails, send response

    # Save file descriptor
    mov [file_fd], rax

    # Read file
    lea rsi, [file_buffer]
    mov rdi, [file_fd]
    mov rdx, 1024             # Buffer size
    mov rax, 0                # SYS_read
    syscall

    # register file size
    mov [file_size], rax

    # Close file
    mov rdi, [file_fd]              # File descriptor
    mov rax, 3                # SYS_close
    syscall

send_response:
    # Send HTTP header
    lea rsi, [response_header]
    mov rdi, [client_fd]
    mov rdx, 19               # Length of response header
    mov rax, 1                # SYS_write
    syscall

    # Send file content
    lea rsi, [file_buffer]
    mov rdx, [file_size]             # Assuming full buffer write
    mov rax, 1                # SYS_write
    syscall

    # Close client socket
    mov rdi, [client_fd]              # Client socket file descriptor
    mov rax, 3                # SYS_close
    syscall

exit:
    # Exit program
    xor rdi, rdi              # Exit code 0
    mov rax, 60               # SYS_exit
    syscall

.section .data
sockaddr_in:
    .byte 2                   # AF_INET
    .byte 0
    .byte 0
    .short 0x0050             # Port 80 (HTTP)
    .int 0                    # INADDR_ANY

response_header:
    .asciz "HTTP/1.0 200 OK\r\n\r\n"

request_buffer:
    .space 1024

file_buffer:
    .space 1024
