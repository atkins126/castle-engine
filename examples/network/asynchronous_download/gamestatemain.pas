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

{ Main state, where most of the application logic takes place. }
unit GameStateMain;

interface

uses CastleUIState, CastleScene, CastleControls,
  CastleKeysMouse, CastleColors, CastleViewport, CastleUIControls,
  CastleDownload;

type
  { Main state, where most of the application logic takes place. }
  TStateMain = class(TUIState)
  strict private
    const
      DownloadsCount = 3;
    var
      { Components designed using CGE editor, loaded from state_main.castle-user-interface. }
      LabelDownload: array [1..DownloadsCount] of TCastleLabel;
      ProgressDownload: array [1..DownloadsCount] of TCastleRectangleControl;
      ButtonStartDownloads, ButtonAbortDownloads: TCastleButton;
      LabelStatus: TCastleLabel;

      Download: array [1..DownloadsCount] of TCastleDownload;
    procedure ClickStartDownloads(Sender: TObject);
    procedure ClickAbortDownloads(Sender: TObject);
    procedure DownloadFinish(const Sender: TCastleDownload; var FreeSender: Boolean);
    procedure UpdateDownloadState;
  public
    procedure Start; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
  end;

var
  StateMain: TStateMain;

implementation

uses SysUtils, Classes, Math,
  {$ifndef VER3_0} OpenSSLSockets, {$endif} // https support
  CastleComponentSerialize, CastleUtils, CastleStringUtils, CastleLog,
  CastleURIUtils;

{ TStateMain ----------------------------------------------------------------- }

procedure TStateMain.Start;
var
  UiOwner: TComponent;
begin
  inherited;

  { Load designed user interface }
  InsertUserInterface('castle-data:/state_main.castle-user-interface', FreeAtStop, UiOwner);

  { Find components, by name, that we need to access from code }
  ButtonStartDownloads := UiOwner.FindRequiredComponent('ButtonStartDownloads') as TCastleButton;
  ButtonAbortDownloads := UiOwner.FindRequiredComponent('ButtonAbortDownloads') as TCastleButton;
  LabelDownload[1] := UiOwner.FindRequiredComponent('LabelDownload1') as TCastleLabel;
  LabelDownload[2] := UiOwner.FindRequiredComponent('LabelDownload2') as TCastleLabel;
  LabelDownload[3] := UiOwner.FindRequiredComponent('LabelDownload3') as TCastleLabel;
  ProgressDownload[1] := UiOwner.FindRequiredComponent('ProgressDownload1') as TCastleRectangleControl;
  ProgressDownload[2] := UiOwner.FindRequiredComponent('ProgressDownload2') as TCastleRectangleControl;
  ProgressDownload[3] := UiOwner.FindRequiredComponent('ProgressDownload3') as TCastleRectangleControl;
  LabelStatus := UiOwner.FindRequiredComponent('LabelStatus') as TCastleLabel;

  ButtonStartDownloads.OnClick := @ClickStartDownloads;
  ButtonAbortDownloads.OnClick := @ClickAbortDownloads;

  UpdateDownloadState;
end;

procedure TStateMain.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  LabelStatus.Caption := 'FPS: ' + Container.Fps.ToString;
  UpdateDownloadState;
end;

procedure TStateMain.ClickStartDownloads(Sender: TObject);
const
  Urls: array [1..DownloadsCount] of String = (
    'https://castle-engine.io/latest.zip',
    'https://castle-engine.io/modern_pascal_introduction.html',
    'https://en.wikipedia.org/wiki/Main_Page'
    // 'file:///home/michalis/sources/castle-engine/castle-engine/examples/network/asynchronous_download/data/gears.blend',
    // 'castle-data:/gears.gltf',
    // 'https://deliberately-invalid-server.org/deliberately-invalid-url'
    // 'https://castle-engine.io/deliberately-invalid-url',
    // 'http://example.org/',
    // 'https://github.com/castle-engine/castle-engine/'
  );
var
  I: Integer;
begin
  for I := 1 to DownloadsCount do
  begin
    FreeAndNil(Download[I]);
    Download[I] := TCastleDownload.Create(Self);
    Download[I].Url := Urls[I];
    Download[I].OnFinish := @DownloadFinish;

    { Without soForceMemoryStream, returns as soon as possible with
      any stream class. This may give you e.g.:

      - TFileStream for normal files. Which is usually fine for normal reading,
        but note that underlying TFileStream may prevent from keeping
        the same file open multiple times in multiple TFileStream instances.

      - If you would use soGzip, then it may give you TGZFileStream
        which is not "seekable", i.e. you cannot freely move within the stream.

      Using soForceMemoryStream guarantees you get TMemoryStream which is easy
      to handle, always seekable etc.
    }
    //Download[I].Options := [soForceMemoryStream];

    Download[I].Start;
  end;
end;

procedure TStateMain.DownloadFinish(const Sender: TCastleDownload; var FreeSender: Boolean);
begin
  if Sender.Status = dsError then
    WritelnLog('Downloading "%s" failed: %s.' + NL +
      'HTTP response code: %d' + NL +
      'HTTP response headers: %s', [
      URIDisplay(Sender.Url),
      Sender.ErrorMessage,
      Sender.HttpResponseCode,
      Sender.HttpResponseHeaders.Text
    ])
  else
    WritelnLog('Downloading "%s" successful.' + NL +
      'HTTP response code: %d' + NL +
      'HTTP response headers: %s', [
      URIDisplay(Sender.Url),
      Sender.HttpResponseCode,
      Sender.HttpResponseHeaders.Text
    ]);
end;

procedure TStateMain.ClickAbortDownloads(Sender: TObject);
var
  I: Integer;
begin
  for I := 1 to DownloadsCount do
    FreeAndNil(Download[I]);
end;

procedure TStateMain.UpdateDownloadState;
const
  StatusToStr: array [TDownloadStatus] of String = (
    { The "Not Started" from here will never be visible, as we call TCastleDownload.Start
      right after creating it. }
    'Not Started',
    'Downloading',
    'Error',
    'Success'
  );
var
  I: Integer;
begin
  for I := 1 to DownloadsCount do
  begin
    if Download[I] = nil then
    begin
      LabelDownload[I].Caption := 'Not started (or aborted)';
      ProgressDownload[I].Exists := false;
    end else
    begin
      LabelDownload[I].Text.Clear;
      LabelDownload[I].Text.Add('Downloading: ' + Download[I].Url);
      LabelDownload[I].Text.Add('Status: ' + StatusToStr[Download[I].Status]);
      if Download[I].Status = dsError then
        LabelDownload[I].Text.AddMultiLine('Error message: ' + Download[I].ErrorMessage)
      else
        // ErrorMessage should only be set if Status is dsError
        Assert(Download[I].ErrorMessage = '');
      LabelDownload[I].Text.Add(Format('Downloaded size: %s / %s (bytes: %d / %d)', [
        SizeToStr(Download[I].DownloadedBytes),
        SizeToStr(Download[I].TotalBytes),
        Download[I].DownloadedBytes,
        Download[I].TotalBytes
      ]));
      LabelDownload[I].Text.Add('MIME type: ' + Download[I].MimeType);

      ProgressDownload[I].Exists := true;
      if Download[I].Status in [dsDownloading, dsSuccess] then
      begin
        ProgressDownload[I].Color := HexToColor('399100E6');

        if Download[I].Status = dsSuccess then
          { Regardless of TotalBytes (which may remain -1 if server never reported them)
            report progress as finished when dsSuccess. }
          ProgressDownload[I].WidthFraction := 1
        else
        if Download[I].TotalBytes > 0 then
          { Note that when WidthFraction = 0, then WidthFraction is ignored,
            and the Width property determines size.
            But ProgressDownload[I].Width is always 0 (set in editor).
            So WidthFraction = 0 reliably hides the bar. }
          ProgressDownload[I].WidthFraction := Download[I].DownloadedBytes / Download[I].TotalBytes
        else
          ProgressDownload[I].WidthFraction := 0;
      end else
      begin
        ProgressDownload[I].Color := HexToColor('FF0000E6');
        ProgressDownload[I].WidthFraction := 1;
      end;
    end;
  end;
end;

end.
