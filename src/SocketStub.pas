unit SocketStub;

(*
***************************************************************************
 coroutine for Delphi 
 Copyright (c) 2019-2019 zhouzuoji(zhouzouji@outlook.com)
                                                                       
 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the       
 "Software"), to deal in the Software without restriction, including   
 without limitation the rights to use, copy, modify, merge, publish,   
 distribute, sublicense, and/or sell copies of the Software, and to    
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:                                             
                                                                       
 The above copyright notice and this permission notice shall be        
 included in all copies or substantial portions of the Software.       
                                                                       
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF    
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY  
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,  
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE     
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                
***************************************************************************
*)

interface

uses
  SysUtils, Classes, Windows, Winsock2;

function socket_create(af, type_, protocol: Integer): TSocket;
function socket_accept(s: TSocket; addr: PSockAddr; addrlen: PINT): TSocket;
function socket_connect(s: TSocket; var name: TSockAddr; namelen: Integer): Integer;
function socket_send(s: TSocket; const buf; len, flags: Integer): Integer;
function socket_recv(s: TSocket; var buf; len, flags: Integer): Integer;

implementation

uses
  coroutine;

type
  LPFN_ACCEPTEX = function(sListenSocket, sAcceptSocket: TSocket;
    lpOutputBuffer: Pointer;
    dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD;
    lpdwBytesReceived: PCardinal; lpOverlapped: POVERLAPPED): BOOL; stdcall;
  TFnAcceptEx = LPFN_ACCEPTEX;

  LPFN_GETACCEPTEXSOCKADDRS = procedure(lpOutputBuffer: Pointer;
    dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD;
    var LocalSockaddr: LPSOCKADDR;
    var LocalSockaddrLength: Integer; var RemoteSockaddr: LPSOCKADDR;
    var RemoteSockaddrLength: Integer); stdcall;
  TFnGetAcceptExSockAddrs = LPFN_GETACCEPTEXSOCKADDRS;

  LPFN_CONNECTEX = function(s: TSocket; const name: SockAddr; namelen: Integer;
    lpSendBuffer: Pointer; dwSendDataLength: DWORD;
    var lpdwBytesSent: DWORD; lpOverlapped: POVERLAPPED): BOOL; stdcall;

var
  AcceptEx: LPFN_ACCEPTEX = nil;
  GetAcceptExSockAddrs: LPFN_GETACCEPTEXSOCKADDRS = nil;
  ConnectEx: LPFN_CONNECTEX = nil;

function socket_create(af, type_, protocol: Integer): TSocket;
begin
  Result := WSASocket(af, type_, protocol, nil, 0, WSA_FLAG_OVERLAPPED);
  RegisterIOCP(Result);
end;

function socket_accept(s: TSocket; addr: PSockAddr; addrlen: PINT): TSocket;
const
  MIN_ACCEPTEX_BUFFER = 128;
var
  c: PCoroutineContext;
  lvBytesTransferred, lvFlags: Cardinal;
  buf: array [0..MIN_ACCEPTEX_BUFFER-1] of AnsiChar;
  lvOverlapped: TOverlappedEx;
  lvLastError: Integer;
begin
  c := coroutine_current;
  if not Assigned(c) then
  begin
    Result := Winsock2.accept(s, addr, addrlen);
    Exit;
  end;
  Result := socket_create(AF_INET, SOCK_STREAM, 0);
  FillChar(lvOverlapped, SizeOf(lvOverlapped), 0);
  lvOverlapped.c := c;
  lvBytesTransferred := 0;
  if AcceptEx(s, Result, @buf, 0, SizeOf(TSockAddr) + 16, SizeOf(TSockAddr) + 16,
    @lvBytesTransferred, @lvOverlapped) then
  begin

    coroutine_wait(c);
    Exit;
  end;

  lvLastError := WSAGetLastError;
  if WSA_IO_PENDING <> lvLastError then
  begin
    Winsock2.closesocket(Result);
    Result := INVALID_SOCKET;
    Exit;
  end;


  coroutine_wait(c);
  lvFlags := 0;
  if not WSAGetOverlappedResult(s, @lvOverlapped, lvBytesTransferred, False, lvFlags) then
  begin
    Writeln('AcceptEx failed: ', WSAGetLastError);
    Winsock2.closesocket(Result);
    Result := INVALID_SOCKET;
  end;
end;

function socket_connect(s: TSocket; var name: TSockAddr; namelen: Integer): Integer;
var
  c: PCoroutineContext;
  lvBytesTransferred, lvFlags: Cardinal;
  lvOverlapped: TOverlappedEx;
  lvLastError: Integer;
begin
  c := coroutine_current;
  if not Assigned(c) then
  begin
    Result := Winsock2.connect(s, name, namelen);
    Exit;
  end;
  Result := 0;
  FillChar(lvOverlapped, SizeOf(lvOverlapped), 0) ;
  lvOverlapped.c := c;
  lvBytesTransferred := 0;
  if ConnectEx(s, name, namelen, nil, 0, lvBytesTransferred, @lvOverlapped) then
  begin

    coroutine_wait(c);
    Exit;
  end;

  lvLastError := WSAGetLastError;
  if WSA_IO_PENDING <> lvLastError then
  begin
    Result := -1;
    Exit;
  end;


  coroutine_wait(c);
  lvFlags := 0;
  if not WSAGetOverlappedResult(s, @lvOverlapped, lvBytesTransferred, False, lvFlags) then
    Result := -1;
end;

function socket_send(s: TSocket; const buf; len, flags: Integer): Integer;
var
  c: PCoroutineContext;
  lvBytesTransferred, lvFlags: Cardinal;
  lvOverlapped: TOverlappedEx;
  lvLastError: Integer;
  lvBuf: WSABUF;
begin
  c := coroutine_current;
  if not Assigned(c) then
  begin
    Result := Winsock2.send(s, buf, len, flags);
    Exit;
  end;
  FillChar(lvOverlapped, SizeOf(lvOverlapped), 0) ;
  lvOverlapped.c := c;
  lvBytesTransferred := 0;
  lvBuf.buf := PAnsiChar(@buf);
  lvBuf.len := len;
  Result := WSASend(s, @lvBuf, 1, lvBytesTransferred, flags, @lvOverlapped, nil);

  if Result = 0 then
  begin
    Result := lvBytesTransferred;

    coroutine_wait(c);
    Exit;
  end;

  lvLastError := WSAGetLastError;
  if WSA_IO_PENDING <> lvLastError then
  begin
    Result := -1;
    Exit;
  end;


  coroutine_wait(c);
  lvFlags := 0;
  if WSAGetOverlappedResult(s, @lvOverlapped, lvBytesTransferred, False, lvFlags) then
    Result := lvBytesTransferred
  else
    Result := -1;
end;

function socket_sendto(s: TSocket; const buf; len, flags: Integer; toaddr: PSockAddr; tolen: Integer): Integer;
begin
  Result := Winsock2.sendto(s, buf, len, flags, toaddr, tolen);
end;

function socket_recv(s: TSocket; var buf; len, flags: Integer): Integer;
var
  c: PCoroutineContext;
  lvBytesTransferred, lvFlags: Cardinal;
  lvOverlapped: TOverlappedEx;
  lvLastError: Integer;
  lvBuf: WSABUF;
begin
  c := coroutine_current;
  if not Assigned(c) then
  begin
    Result := Winsock2.recv(s, buf, len, flags);
    Exit;
  end;
  FillChar(lvOverlapped, SizeOf(lvOverlapped), 0) ;
  lvOverlapped.c := c;
  lvBytesTransferred := 0;
  lvBuf.buf := PAnsiChar(@buf);
  lvBuf.len := len;
  Result := WSARecv(s, @lvBuf, 1, lvBytesTransferred, DWORD(flags), @lvOverlapped, nil);

  if Result = 0 then
  begin
    Result := lvBytesTransferred;

    coroutine_wait(c);
    Exit;
  end;

  lvLastError := WSAGetLastError;
  if WSA_IO_PENDING <> lvLastError then
  begin
    Result := -1;
    Exit;
  end;

  coroutine_wait(c);
  lvFlags := 0;
  if WSAGetOverlappedResult(s, @lvOverlapped, lvBytesTransferred, False, lvFlags) then
    Result := lvBytesTransferred
  else
    Result := -1;
end;

procedure GetExtensionFunction(s: TSocket; const FuncGuid: TGUID; out FuncAddr: Pointer);
var
  lvBytesReturned: DWORD;
begin
  WSAIoctl(s, SIO_GET_EXTENSION_FUNCTION_POINTER,
    @FuncGuid, SizeOf(FuncGuid), @FuncAddr, SizeOf(FuncAddr),
    lvBytesReturned, nil, nil);
end;

procedure winsock_initialize;
const
  WSAID_ACCEPTEX: TGUID = (
    D1: $B5367DF1; D2: $CBAC; D3: $11CF; D4: ($95, $CA, $00, $80, $5F, $48, $A1, $92));
  WSAID_GETACCEPTEXSOCKADDRS: TGUID = (
    D1: $B5367DF2; D2: $CBAC; D3: $11CF; D4: ($95, $CA, $00, $80, $5F, $48, $A1, $92));
  WSAID_CONNECTEX: TGUID = (
    D1: $25A207B9; D2: $DDF3; D3: $4660; D4: ($8E, $E9, $76, $E5, $8C, $74, $06, $3E));
var
  wsad: TWsaData;
  s: TSocket;
begin
  if SOCKET_ERROR = WSAStartup($0202, wsad) then Exit;
  s := WSASocket(AF_INET, SOCK_STREAM, 0, nil, 0, 0);
  try
    GetExtensionFunction(s, WSAID_ACCEPTEX, Pointer(@AcceptEx));
    GetExtensionFunction(s, WSAID_GETACCEPTEXSOCKADDRS, Pointer(@GetAcceptExSockAddrs));
    GetExtensionFunction(s, WSAID_CONNECTEX, Pointer(@ConnectEx));
  finally
	  closesocket(s);
  end;
end;

initialization
  winsock_initialize;

end.
