{
  Copyright 2021-2021 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Measure loading time of various images. }
unit GameStateSpeedTest;

interface

uses Classes,
  CastleVectors, CastleUIState, CastleUIControls, CastleControls, CastleKeysMouse;

type
  TStateSpeedTest = class(TUIState)
  private
    const
      TestImages: array [0..11] of String = (
        'castle-data:/images/bricks2.jpg',
        'castle-data:/images/crown.gif',
        'castle-data:/images/metal_decal.dds',
        'castle-data:/images/sky_red_back.bmp',
        'castle-data:/images/sky_red_left.ppm',
        'castle-data:/images/sky_red_right.rgbe',
        'castle-data:/images/test_texture_grayscale.png',
        'castle-data:/images/test_texture.png',
        'castle-data:/images/texture_alpha.png',
        'castle-data:/images/test_texture.tga',
        'castle-data:/images/test_texture.xpm',
        'castle-data:/images/rgb-reference.ktx'
      );

    var
      { Components designed using CGE editor, loaded from the castle-user-interface file. }
      ButtonGoView: TCastleButton;
      LabelTestInfo: TCastleLabel;

      TestIndex: Cardinal;

    procedure ClickGoView(Sender: TObject);
    procedure NextTest(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
  end;

var
  StateSpeedTest: TStateSpeedTest;

implementation

uses SysUtils,
  CastleImages, CastleTimeUtils, CastleURIUtils,
  GameStateMain;

constructor TStateSpeedTest.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/gamestatespeedtest.castle-user-interface';
end;

procedure TStateSpeedTest.Start;
begin
  inherited;

  { Find components, by name, that we need to access from code }
  ButtonGoView := DesignedComponent('ButtonGoView') as TCastleButton;
  LabelTestInfo := DesignedComponent('LabelTestInfo') as TCastleLabel;

  ButtonGoView.OnClick := {$ifdef FPC}@{$endif} ClickGoView;

  TestIndex := 0;

  LabelTestInfo.Text.Clear;
  LabelTestInfo.Text.Append('Testing image loading times:');
  LabelTestInfo.Text.Append(''); // add empty line before the rest of tests

  { We use WaitForRenderAndCall to show the speed test results gradually.
    It doesn't really improve the functionality, but it looks better. }
  WaitForRenderAndCall({$ifdef FPC}@{$endif} NextTest);
end;

procedure TStateSpeedTest.ClickGoView(Sender: TObject);
begin
  TUIState.Current := StateMain;
end;

procedure TStateSpeedTest.NextTest(Sender: TObject);
const
  TestsCountDefault = 100;
  TestsCountXpm = 5; // XPM loading is *very* slow, smaller amount of tests is enough
var
  Img: TEncodedImage;
  I, TestsCount: Integer;
  TimeStart: TTimerResult;
  Seconds: TFloatTime;
  ImgInfo: String;
begin
  TimeStart := Timer;
  if ExtractFileExt(TestImages[TestIndex]) = '.xpm' then
    TestsCount := TestsCountXpm
  else
    TestsCount := TestsCountDefault;
  for I := 1 to TestsCount do
  begin
    Img := LoadEncodedImage(TestImages[TestIndex]);
    if I = 1 then
      ImgInfo := Format('%s, %dx%d', [
        Img.ClassName,
        Img.Width,
        Img.Height
      ]);
    FreeAndNil(Img);
  end;
  Seconds := TimeStart.ElapsedTime;

  LabelTestInfo.Text.Append(Format('%s: Loaded in %f secs (%d times). Image loaded as %s', [
    URICaption(TestImages[TestIndex]),
    Seconds,
    TestsCount,
    ImgInfo
  ]));

  Inc(TestIndex);
  if TestIndex <= High(TestImages) then
    WaitForRenderAndCall({$ifdef FPC}@{$endif} NextTest)
  else
  begin
    LabelTestInfo.Text.Append('');
    LabelTestInfo.Text.Append('Tests finished.');
  end;
end;

end.
