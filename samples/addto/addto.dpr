program addto;

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
  coroutine in '..\..\src\coroutine.pas';

procedure loop_add1(avParam: Pointer);
begin
  while PInteger(avParam)^ < 1000 do
  begin
    Inc(PInteger(avParam)^, 1);
    Writeln(PInteger(avParam)^);
    coroutine_yield;
  end;
end;

procedure loop_add2(avParam: Pointer);
begin
  while PInteger(avParam)^ < 1000 do
  begin
    Inc(PInteger(avParam)^, 2);
    Writeln(PInteger(avParam)^);
    coroutine_yield;
  end;
end;

var
  gNumber: Integer;
begin
  Randomize;
  System.ReportMemoryLeaksOnShutdown := True;
  try
    coroutine.coroutine_create(@loop_add1, @gNumber);
    coroutine.coroutine_create(@loop_add2, @gNumber);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  Writeln('press enter to exit...');
  Readln;
end.
