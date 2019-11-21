program tcp;

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
 
{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Winsock2,
  coroutine in '..\..\src\coroutine.pas',
  SocketStub in '..\..\src\SocketStub.pas';

procedure ServerConnectionHandler(avParam: Pointer);
var
  s: TSocket;
  question: array [0..1] of Integer;
  answer: Integer;
  n: Integer;
begin
  s := TSocket(avParam);
  while True do
  begin
    n := socket_recv(s, question, SizeOf(question), 0);

    if n = 0 then
    begin
      Writeln('connection closed gracefully');
      Exit;
    end;

    if n < 0 then
    begin
      Writeln('recv error: ', WSAGetLastError);
      Exit;
    end;

    answer := question[0] + question[1];
    if SOCKET_ERROR = socket_send(s, answer, SizeOf(answer), 0) then
    begin
      Writeln('send error: ', WSAGetLastError);
      Exit;
    end;
  end;
end;

procedure TcpServerHandler(avParam: Pointer);
var
  s, conn: TSocket;
  sa: TSockAddrIn;
  salen: Integer;
begin
  s := socket_create(AF_INET, SOCK_STREAM, 0);
  salen := SizeOf(sa);
  FillChar(sa, salen, 0);
  sa.sin_family := AF_INET;
  sa.sin_port := htons(7890);

  Winsock2.bind(s, sockaddr(sa), salen);
  Winsock2.listen(s, 100);
  while True do
  begin
    salen := SizeOf(sa);
    conn := socket_accept(s, @sa, @salen);
    if conn <> INVALID_SOCKET then
      coroutine_create(ServerConnectionHandler, Pointer(conn))
    else
      Writeln('accept error: ', WSAGetLastError);
  end;
end;

procedure TcpClientHandler(avParam: Pointer);
var
  s: TSocket;
  sa: TSockAddrIn;
  salen, n, i: Integer;
  question: array [0..1] of Integer;
  answer: Integer;
begin
  s := socket_create(AF_INET, SOCK_STREAM, 0);
  salen := SizeOf(sa);
  FillChar(sa, salen, 0);
  sa.sin_family := AF_INET;
  Winsock2.bind(s, sockaddr(sa), salen);

  sa.sin_port := htons(7890);
  sa.sin_addr.S_addr := inet_addr('127.0.0.1');
  if -1 = socket_connect(s, sockaddr(sa), salen) then
  begin
    Writeln('connect error: ', WSAGetLastError);
    Exit;
  end;

  for i := 1 to 1000 do
  begin
    question[0] := Random($7fffffff);
    question[1] := Random($7fffffff);
    if SOCKET_ERROR = socket_send(s, question, SizeOf(question), 0) then
    begin
      Writeln('send error: ', WSAGetLastError);
      Exit;
    end;
    n := socket_recv(s, answer, SizeOf(answer), 0);

    if n = 0 then
    begin
      Writeln('connection closed gracefully');
      Exit;
    end;

    if n < 0 then
    begin
      Writeln('recv error: ', WSAGetLastError);
      Exit;
    end;

    Assert(answer=question[0]+question[1]);
    Writeln(Format('server compute: %d + %d = %d', [question[0], question[1], answer]));
  end;

  Winsock2.closesocket(s);
end;

var
  i: Integer;
begin
  Randomize;
  System.ReportMemoryLeaksOnShutdown := True;
  try
    coroutine.coroutine_create(@TcpServerHandler, nil);
    for i := 1 to 100 do
      coroutine.coroutine_create(@TcpClientHandler, nil);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  Writeln('press enter to exit...');
  Readln;
end.
