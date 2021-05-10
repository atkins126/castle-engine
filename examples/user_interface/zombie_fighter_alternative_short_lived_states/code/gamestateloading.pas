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

{ State with sample loading. }
unit GameStateLoading;

interface

uses Classes, CastleControls, CastleUIState;

type
  { Loading state.
    This is an example how to show a loading progress using TStateLoading.

    As an example, it assumes that your "loading" consists of
    - one call to DoLoadSomething1
    - one call to DoLoadSomething2
    - 17 calls to DoLoadSomethingSmall
  }
  TStateLoading = class(TUIState)
  strict private
    const
      FakeLoadingAdditionalStepsCount = 17;
    var
      LabelPercent: TCastleLabel;
      { Variable that simulates loading progress,
        we will grow it from 0 to FakeLoadingAdditionalStepsCount during loading. }
      FakeLoadingAdditionalSteps: Cardinal;
      LoadingFinished: Boolean;
    procedure UpdateProgress(const Progress: Single);
    procedure DoLoadSomething1(Sender: TObject);
    procedure DoLoadSomething2(Sender: TObject);
    procedure DoLoadSomethingSmall(Sender: TObject);
    procedure DoLoadingFinish(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
  end;

implementation

uses SysUtils,
  CastleColors, CastleWindow, CastleUIControls, CastleFilesUtils, CastleApplicationProperties,
  CastleUtils, CastleComponentSerialize,
  GameStatePlay;

{ TStateLoading ------------------------------------------------------------- }

constructor TStateLoading.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/gamestateloading.castle-user-interface';
end;

procedure TStateLoading.Start;
begin
  inherited;

  { Find components, by name, that we need to access from code }
  LabelPercent := DesignedComponent('LabelPercent') as TCastleLabel;

  LoadingFinished := false;
  FakeLoadingAdditionalSteps := 0;
  UpdateProgress(0);
  WaitForRenderAndCall(@DoLoadSomething1);
end;

procedure TStateLoading.UpdateProgress(const Progress: Single);
begin
  LabelPercent.Caption := IntToStr(Round(100 * Progress)) + '%';
end;

procedure TStateLoading.DoLoadSomething1(Sender: TObject);
begin
  { Fake loading something big, one time. Just do something time-consuming there. }
  Sleep(100);

  UpdateProgress(0.25);
  WaitForRenderAndCall(@DoLoadSomething2);
end;

procedure TStateLoading.DoLoadSomething2(Sender: TObject);
begin
  { Fake loading something big, one time. Just do something time-consuming there. }
  Sleep(100);

  UpdateProgress(0.5);
  WaitForRenderAndCall(@DoLoadSomethingSmall);
end;

procedure TStateLoading.DoLoadSomethingSmall(Sender: TObject);
begin
  { Fake loading something small, 17 times (FakeLoadingAdditionalStepsCount).
    Just do something time-consuming there. }
  Sleep(5);

  Inc(FakeLoadingAdditionalSteps);
  UpdateProgress(0.5 + 0.5 * FakeLoadingAdditionalSteps / FakeLoadingAdditionalStepsCount);
  if FakeLoadingAdditionalSteps = FakeLoadingAdditionalStepsCount then
    { Finished loading. Using WaitForRenderAndCall(@DoFinish)
      means that user can see the value "100%", otherwise it would never get drawn,
      and the last loading frame would always show "97%". }
    WaitForRenderAndCall(@DoLoadingFinish)
  else
    WaitForRenderAndCall(@DoLoadSomethingSmall); // call this again, to load next step
end;

procedure TStateLoading.DoLoadingFinish(Sender: TObject);
begin
  { Finished loading, go to StatePlay.

    In case of using CreateUntilStopped, you cannot change state
    inside a WaitForRenderAndCall callback.
    So we need additional flag LoadingFinished to mark this state,
    that is handled in Update.
    This is more straightforward in version without CreateUntilStopped,
    in examples/zombie_fighter/ . }
  LoadingFinished := true;
end;

procedure TStateLoading.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  if LoadingFinished then
    TUIState.Current := TStatePlay.CreateUntilStopped;
end;

end.
