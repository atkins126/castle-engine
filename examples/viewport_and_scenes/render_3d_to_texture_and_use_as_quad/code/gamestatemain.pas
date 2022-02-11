{
  Copyright 2016-2021 Michalis Kamburelis.

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

uses Classes,
  CastleVectors, CastleUIState, CastleComponentSerialize,
  CastleUIControls, CastleControls, CastleKeysMouse, CastleViewport, CastleScene;

type
  { Main state, where most of the application logic takes place. }
  TStateMain = class(TUIState)
  private
    { Components designed using CGE editor, loaded from gamestatemain.castle-user-interface. }
    LabelFps: TCastleLabel;
    SourceViewport: TCastleViewport;
    DisplayedScene: TCastleScene;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
  end;

var
  StateMain: TStateMain;

implementation

uses SysUtils, X3DNodes,
  CastleImages, CastleGLImages, CastleRectangles;

{ TStateMain ----------------------------------------------------------------- }

constructor TStateMain.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/gamestatemain.castle-user-interface';
end;

procedure TStateMain.Start;

  { Load and render a 3D scene to a new texture. }
  function CreateSpriteTexture: TCastleImage;
  const
    TextureWidth = 1024;
    TextureHeight = TextureWidth;
  var
    RenderToTexture: TGLRenderToTexture;
    ViewportRect: TRectangle;
  begin
    RenderToTexture := TGLRenderToTexture.Create(TextureWidth, TextureHeight);
    try
      RenderToTexture.Buffer := tbNone;
      RenderToTexture.GLContextOpen;
      RenderToTexture.RenderBegin;

      ViewportRect := Rectangle(0, 0, TextureWidth, TextureHeight);

      { Everything rendered between RenderToTexture.RenderBegin ... RenderToTexture.RenderEnd
        is done off-screen.
        Below, we explicitly render the SourceViewport. }
      SourceViewport.Exists := true;
      StateContainer.RenderControl(SourceViewport, ViewportRect);
      SourceViewport.Exists := false; // hide it back

      Result := SaveScreen_NoFlush(TRGBImage, ViewportRect, RenderToTexture.ColorBuffer);

      RenderToTexture.RenderEnd;
    finally FreeAndNil(RenderToTexture) end;
  end;

var
  SpriteTexture: TCastleImage;
  DisplayedAppearance: TAppearanceNode;
  DisplayedMaterial: TPhysicalMaterialNode;
  NewTexture: TPixelTextureNode;
begin
  inherited;

  { Find components, by name, that we need to access from code }
  LabelFps := DesignedComponent('LabelFps') as TCastleLabel;
  SourceViewport := DesignedComponent('SourceViewport') as TCastleViewport;
  DisplayedScene := DesignedComponent('DisplayedScene') as TCastleScene;

  { render to texture }
  SpriteTexture := CreateSpriteTexture;
  // You could save the image to disk at this point.
  // SaveImage(SpriteTexture, 'test.png');

  { set SpriteTexture to be used by DisplayedScene }

  { We use material name "MatTexturedShape" set in Blender.
    Blender exports it to glTF,
    and it results in TAppearanceNode called "MatTexturedShape". }
  DisplayedAppearance := DisplayedScene.Node('MatTexturedShape') as TAppearanceNode;
  { We know that Blender records PBR material in glTF. }
  DisplayedMaterial := DisplayedAppearance.Material as TPhysicalMaterialNode;

  { create new TPixelTextureNode and set it as DisplayedMaterial.BaseTexture }
  NewTexture := TPixelTextureNode.Create;
  NewTexture.FdImage.Value := SpriteTexture;
  // NewTexture.RepeatS := false;
  // NewTexture.RepeatT := false;
  DisplayedMaterial.BaseTexture := NewTexture;
end;

procedure TStateMain.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  { This virtual method is executed every frame.}
  LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;
end;

end.
