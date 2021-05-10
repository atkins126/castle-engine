{
  Copyright 2020-2020 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Game initialization and logic. }
unit GameInitialize;

interface

implementation

uses SysUtils, Math, Classes,
  {$ifndef VER3_0} OpenSSLSockets, {$endif} // support HTTPS
  CastleWindow, CastleLog, CastleApplicationProperties, CastleUIState,
  GameStateMain, GameLogHandler;

var
  Window: TCastleWindowBase;
  LogHandler: TLogHandler;

{ One-time initialization of resources. }
procedure ApplicationInitialize;
begin
  { Initialize LogHandler }
  LogHandler := TLogHandler.Create(Application);
  ApplicationProperties.OnLog.Add(@LogHandler.LogCallback);

  { Adjust container settings for a scalable UI (adjusts to any window size in a smart way). }
  Window.Container.LoadSettings('castle-data:/CastleSettings.xml');

  StateMain := TStateMain.Create(Application);
  TUIState.Current := StateMain;
end;

initialization
  { Initialize Application.OnInitialize. }
  Application.OnInitialize := @ApplicationInitialize;

  { Create and assign Application.MainWindow. }
  Window := TCastleWindowBase.Create(Application);
  Window.ParseParameters; // allows to control window size / fullscreen on the command-line
  Application.MainWindow := Window;
end.
