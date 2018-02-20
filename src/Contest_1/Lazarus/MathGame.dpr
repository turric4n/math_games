program MathGame;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$APPTYPE CONSOLE}

{$I Synopse.inc}

{$R *.res}

//{$MAXSTACKSIZE 2147483647}

uses
  {$IFNDEF FPC}
  System.SysUtils,
  System.Classes,
  {$ELSE}
  SysUtils,
  Classes,
  SynCommons,
  {$ENDIF}
  SynCrtSock,
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  Nullpobug.ArgumentParser;

type
  THTTPRespCodes = (rcOK = 200, rcBadRequest = 400, rcNotFound = 404, rcServerError = 503);

  TCore = class
    public
      class procedure ParseArgs;
      class procedure StartServer;
      class procedure ShowHelp;
  end;

  TCustomHTTPServer = class(THttpServer)
    public
      constructor Create;
    published
      function Process(Ctxt: THttpServerRequest) : Cardinal;
      function DoWork(Ctxt: THttpServerRequest; const Iterations : Int64 ) : Cardinal;
  end;

  TModel = record
    ID : Integer;
  end;

  TModelArray = array of TModel;

var
  HTTPServerTP : Integer;
  HTTPServerPort : Integer;
  Iterations : Integer;
  Server : TCustomHTTPServer;
  Msg: TMsg;
  Chunks : Integer;

const
  DEFAULTITERATIONS = 10000;
  ITERATIONSPERTHREAD = 1000;

{ TCustomHTTPServer }

constructor TCustomHTTPServer.Create;
begin
  inherited Create(HTTPServerPort.ToString, nil, nil, 'MathGame', HTTPServerTP);
  ServerName := 'Turrican server';
  OnRequest := Process;
end;

function TCustomHTTPServer.DoWork(Ctxt: THttpServerRequest; const Iterations : Int64 ) : Cardinal;
var
  models : array of TModel;
  I : Int64;
begin
   try
     //Seed register?
     Randomize;
     //Fix array
     SetLength(models, Iterations);
     for I := 0 to Iterations - 1 do
     begin
       models[i].ID := Random(100);
     end;

     //Return JSON response header
     Ctxt.OutContentType := 'application/json';
     //Return stream
     Ctxt.OutContent := DynArraySaveJSON(models, TypeInfo(TModelArray), False);
     //Return code
     Result := Cardinal(THTTPRespCodes.rcOK);
   except
      on e : Exception do
      begin
        Ctxt.OutContent := e.Message + ' aqui casca';
        Result := Cardinal(THTTPRespCodes.rcServerError);
      end;
   end;
end;

function TCustomHTTPServer.Process(Ctxt: THttpServerRequest): Cardinal;
var
  parameters : TArray<String>;
  parameter : Int64;
  method : string;
begin
  //Process Request
  Result := (Cardinal(THTTPRespCodes.rcNotFound));
  parameters := string(Ctxt.URL).Substring(1).Split(['/']);
  if Ctxt.Method <> 'GET' then Result := (Cardinal(THTTPRespCodes.rcBadRequest))
  else if High(parameters) < 0 then Result := (Cardinal(THTTPRespCodes.rcNotFound))
  else
  begin
    Result := 0;
    method := parameters[0];
    if method <> 'math' then Result := (Cardinal(THTTPRespCodes.rcNotFound))
    else if Length(parameters) < 2 then parameter := DEFAULTITERATIONS
    else if not Int64.TryParse(parameters[1], parameter) then Result := (Cardinal(THTTPRespCodes.rcBadRequest));
    if Result = 0 then Result := DoWork(Ctxt, parameter);
  end;
end;

{ TCore }

class procedure TCore.ParseArgs;
begin
  //Args... bla bla bla...
  with TArgumentParser.Create do
  begin
    try
      AddArgument('--port', 'port', saStore);
      AddArgument('--threads', 'threads', saStore);
      AddArgument('--help', 'help', saBool);
      AddArgument('--debug', 'debug', saBool);
      with ParseArgs do
      begin
        if HasArgument('help') then TCore.ShowHelp;
        if not HasArgument('port') then raise Exception.Create('Missing --port parameter')
        else
        begin
          if not Integer.TryParse(GetValue('port'), HTTPServerPort) then raise Exception.Create('Invalid --port parameter')
          else if (HTTPServerPort > High(Word)) or (HTTPServerPort <= 0) then raise Exception.Create('Invalid --port parameter');
        end;
      end;
    finally
      Free;
    end;
  end;
end;

class procedure TCore.ShowHelp;
begin
  Writeln('--port HTTP TCP binding port.');
  Writeln('--debug Shows debug information under console.');
  Writeln('--help Shows this help.');
end;

class procedure TCore.StartServer;
begin
  Chunks := System.CPUCount;
  HTTPServerTP := System.CPUCount * 2;
  TCustomHTTPServer.Create;
end;

{ Main }

begin
  try
    //Parse arguments
    TCore.ParseArgs;
    //Start HTTPServer
    TCore.StartServer;
    Writeln(Format('HTTPServer started, lisening at 0.0.0.0:%s', [HTTPSERVERPORT.ToString]));
    //Mainloop and pass messages to application
    {$IFDEF WINDOWS}
    while GetMessage(Msg, 0, 0, 0) do
    begin
      TranslateMessage(Msg);
      DispatchMessageA(Msg);
    end;
    {$ELSE}
    readln;
    {$ENDIF}
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message + ' Press a Key to exit...');
      Readln;
    end;
  end;
end.
