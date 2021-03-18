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

{ Simple "menu" user interface, that allows to run the game or quit. }
unit GameStateMenu;

interface

uses Classes,
  CastleUIState, CastleComponentSerialize, CastleUIControls, CastleControls;

type
  { Simple "menu" user interface, that allows to run the game or quit. }
  TStateMenu = class(TUIState)
  private
    ButtonPlay, ButtonQuit: TCastleButton;
    procedure ClickPlay(Sender: TObject);
    procedure ClickQuit(Sender: TObject);
  public
    procedure Start; override;
  end;

var
  StateMenu: TStateMenu;

implementation

uses CastleApplicationProperties, CastleWindow,
  GameStatePlay;

{ TStateMenu ----------------------------------------------------------------- }

procedure TStateMenu.Start;
var
  UiOwner: TComponent;
begin
  inherited;

  { Load designed user interface }
  InsertUserInterface('castle-data:/state_menu.castle-user-interface', FreeAtStop, UiOwner);

  { Find components, by name, that we need to access from code }
  ButtonPlay := UiOwner.FindRequiredComponent('ButtonPlay') as TCastleButton;
  ButtonQuit := UiOwner.FindRequiredComponent('ButtonQuit') as TCastleButton;

  ButtonPlay.OnClick := @ClickPlay;
  ButtonQuit.OnClick := @ClickQuit;
  // Hide "Quit" button on mobile/console platforms, where users don't expect such button
  ButtonQuit.Exists := ApplicationProperties.ShowUserInterfaceToQuit;
end;

procedure TStateMenu.ClickPlay(Sender: TObject);
begin
  TUIState.Current := StatePlay;
end;

procedure TStateMenu.ClickQuit(Sender: TObject);
begin
  Application.Terminate;
end;

end.
