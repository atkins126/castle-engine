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

{ Main "playing game" state, where most of the game logic takes place. }
unit GameStatePlay;

interface

uses Classes,
  CastleUIState, CastleComponentSerialize, CastleUIControls, CastleControls,
  CastleKeysMouse, CastleViewport, CastleScene, CastleVectors, CastleCameras,
  CastleTransform,
  GameEnemy;

type
  { 3rd-person camera navigation.
    Create an instance of this and assign to @link(TCastleViewport.Navigation) to use.
    Be sure to also assign @link(Avatar).

    Moving the mouse allows to orbit with the camera around the avatar.
    When AimAvatar, it also allows to point the avatar at the appropriate direction.
    When not AimAvatar, it allows to look at the avatar easily from any side
    (e.g. you can then see avatar's face easily).

    Using keys AWSD and arrows you can move and rotate the avatar,
    and the camera will follow.

    Using the mouse wheel you can get closer / further to the avatar.
  }
  // TODO: add this to CastleCameras to be automatically in editor
  // TODO expose TVector3 to be published
  // TODO setting related properties during design, should update camera
  TCastleThirdPersonNavigation = class(TCastleMouseLookNavigation)
  strict private
    FAvatar: TCastleScene;
    FAvatarHierarchy: TCastleTransform;
    FMaxAvatarRotationSpeed: Single;
    FInitialHeightAboveTarget: Single;
    FDistanceToAvatarTarget: Single;
    FAimAvatar: Boolean;
    FAvatarTarget: TVector3;
    FAvatarTargetForward: TVector3;
    function RealAvatarHierarchy: TCastleTransform;
    procedure SetAvatar(const Value: TCastleScene);
    procedure SetAvatarHierarchy(const Value: TCastleTransform);
    function CameraPositionInitial(const A: TCastleTransform): TVector3;
  protected
    procedure ProcessMouseLookDelta(const Delta: TVector2); override;
  public
    const
      DefaultInitialHeightAboveTarget = 1.0;
      DefaultDistanceToAvatarTarget = 4.0;
      DefaultMaxAvatarRotationSpeed = 0.1;
      DefaultAvatarTarget: TVector3 = (Data: (0, 2, 0));
      DefaultAvatarTargetForward: TVector3 = (Data: (0, 2, 0));
      { Much smaller defaults than TCastleMouseLookNavigation, as they affect camera differently. }
      DefaultThirdPersonMouseLookHorizontalSensitivity = 0.001;
      DefaultThirdPersonMouseLookVerticalSensitivity = 0.001;

    constructor Create(AOwner: TComponent); override;
    procedure Update(const SecondsPassed: Single;
      var HandleInput: boolean); override;

    { Makes camera be positioned with respect to the current properties and avatar.
      Always call this explicitly once.
      Use this after setting properties like @link(Avatar),
      @link(AvatarHierarchy), @link(DistanceToAvatarTarget),
      @link(InitialHeightAboveTarget).

      TODO: At design-time (in CGE editor), this is automatically called after
      changing relevant properties of this navigation. }
    procedure Init;

    { Translation, from the avatar origin, to the "target" of the avatar where camera
      looks at. This is usually head, and this vector should just describe the height
      of head above the ground.
      By default this is DefaultAvatarTarget = (0, 2, 0). }
    property AvatarTarget: TVector3 read FAvatarTarget write FAvatarTarget;

    { When the camera looks directly behind the avatar's back,
      it points at AvatarTargetForward, not AvatarTarget.
      This allows to place AvatarTargetForward more in forward (and maybe higher/lower)
      than avatar's head.
      This allows to look more "ahead".

      The effective target is a result of lerp between
      AvatarTargetForward and AvatarTarget, depending on how much is camera now close to
      the initial position "looking from the back of avatar".

      The camera is still always rotating around AvatarTarget
      (so you rotate around avatar's head, even if you look far ahead).
      By default this is DefaultAvatarTargetForward = (0, 2, 0). }
    property AvatarTargetForward: TVector3 read FAvatarTargetForward write FAvatarTargetForward;
  published
    property MouseLookHorizontalSensitivity default DefaultThirdPersonMouseLookHorizontalSensitivity;
    property MouseLookVerticalSensitivity default DefaultThirdPersonMouseLookVerticalSensitivity;
    property InvertVerticalMouseLook;

    { Optional avatar hierarchy that is moved and rotated when this navigation changes.
      When this is @nil, we just move and rotate the @link(Avatar).
      When this is non-nil, then we only move and rotate this AvatarHierarchy.

      If @link(AvatarHierarchy) is non-nil, then it should contain
      @link(Avatar) as a child. @link(AvatarHierarchy) can even be equal to @link(Avatar)
      (it is equivalent to just leaving @link(AvatarHierarchy) as @nil). }
    property AvatarHierarchy: TCastleTransform read FAvatarHierarchy write SetAvatarHierarchy;

    { Avatar scene, that is animated, moved and rotated when this navigation changes.
      This navigation component will just call @code(Avatar.PlayAnimation('xxx')) when necessary.
      Currently we require the following animations to exist: walk, idle.

      When AvatarHierarchy is @nil, then @name is directly moved and rotated
      to move avatar.
      Otherwise, AvatarHierarchy is moved, and @name should be inside AvatarHierarchy. }
    property Avatar: TCastleScene read FAvatar write SetAvatar;

    { When @link(AimAvatar), this is avatar's rotation speed.
      Should be small enough to make avatar rotation "catch up" with some delay after camera
      rotation. }
    property MaxAvatarRotationSpeed: Single read FMaxAvatarRotationSpeed write FMaxAvatarRotationSpeed
      default DefaultMaxAvatarRotationSpeed;

    { If @true (default) then rotating the camera also rotates (with some delay) the avatar,
      to face the same direction as the camera.
      This is easier to use for players, on the other hand it takes away some flexibility,
      e.g. you cannot look at avatar's face for a long time anymore. }
    property AimAvatar: Boolean read FAimAvatar write FAimAvatar default true;

    { Initial height of camera above the AvatarTarget.
      Together with DistanceToAvatarTarget this determines the initial camera position,
      set by @link(Init).
      It is not used outside of @link(Init). }
    property InitialHeightAboveTarget: Single read FInitialHeightAboveTarget write FInitialHeightAboveTarget
      default DefaultInitialHeightAboveTarget;

    { Preferred distance from camera to the avatar target (head).
      By default user can change it with mouse wheel. }
    property DistanceToAvatarTarget: Single read FDistanceToAvatarTarget write FDistanceToAvatarTarget
      default DefaultDistanceToAvatarTarget;
  end;

  { Main "playing game" state, where most of the game logic takes place. }
  TStatePlay = class(TUIState)
  private
    { Enemies behaviours }
    Enemies: TEnemyList;

    ThirdPersonNavigation: TCastleThirdPersonNavigation;

    { Components designed using CGE editor, loaded from state-main.castle-user-interface. }
    LabelFps: TCastleLabel;
    MainViewport: TCastleViewport;
    SceneAvatar: TCastleScene;
  public
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  end;

var
  StatePlay: TStatePlay;

implementation

uses SysUtils, Math,
  CastleSoundEngine, CastleLog, CastleStringUtils, CastleFilesUtils, CastleUtils,
  GameStateMenu;

{ TCastleThirdPersonNavigation ----------------------------------------------- }

constructor TCastleThirdPersonNavigation.Create(AOwner: TComponent);
begin
  inherited;
  FAvatarTarget := DefaultAvatarTarget;
  FAvatarTargetForward := DefaultAvatarTargetForward;
  FMaxAvatarRotationSpeed := DefaultMaxAvatarRotationSpeed;
  FAimAvatar := true;
  FInitialHeightAboveTarget := DefaultInitialHeightAboveTarget;
  FDistanceToAvatarTarget := DefaultDistanceToAvatarTarget;
  MouseLookHorizontalSensitivity := DefaultThirdPersonMouseLookHorizontalSensitivity;
  MouseLookVerticalSensitivity := DefaultThirdPersonMouseLookVerticalSensitivity;
end;

function TCastleThirdPersonNavigation.RealAvatarHierarchy: TCastleTransform;
begin
  if AvatarHierarchy <> nil then
    Result := AvatarHierarchy
  else
    Result := Avatar;
end;

procedure TCastleThirdPersonNavigation.SetAvatar(const Value: TCastleScene);
begin
  if FAvatar <> Value then
  begin
    FAvatar := Value;
    // TODO free notification for Avatar, AvatarHierarchy
  end;
end;

procedure TCastleThirdPersonNavigation.SetAvatarHierarchy(const Value: TCastleTransform);
begin
  if FAvatarHierarchy <> Value then
  begin
    FAvatarHierarchy := Value;
    // TODO free notification for Avatar, AvatarHierarchy
  end;
end;

function TCastleThirdPersonNavigation.CameraPositionInitial(const A: TCastleTransform): TVector3;
var
  GravUp: TVector3;

  { Return V rotated such that it is
    orthogonal to GravUp. This way it returns V projected
    on the gravity horizontal plane.
    Result is always normalized (length 1).

    Note that when V and GravUp are parallel,
    this just returns current V --- because in such case
    we can't project V on the horizontal plane. }
  function ToGravityPlane(const V: TVector3): TVector3;
  begin
    Result := V;
    if not VectorsParallel(Result, GravUp) then
      MakeVectorsOrthoOnTheirPlane(Result, GravUp);
  end;

var
  TargetWorldPos, TargetWorldDir: TVector3;
  HorizontalShiftFromTarget: Single;
begin
  TargetWorldPos := A.WorldTransform.MultPoint(AvatarTarget);
  TargetWorldDir := A.WorldTransform.MultDirection(TCastleTransform.DefaultDirection[A.Orientation]);

  { InitialHeightAboveTarget, HorizontalShiftFromTarget, DistanceToAvatarTarget
    create a right triangle, so
    InitialHeightAboveTarget^2 + HorizontalShiftFromTarget^2 = DistanceToAvatarTarget^2
  }
  HorizontalShiftFromTarget := Sqrt(Sqr(DistanceToAvatarTarget) - Sqr(InitialHeightAboveTarget));
  GravUp := Camera.GravityUp;

  Result := TargetWorldPos
    + GravUp * InitialHeightAboveTarget
    - ToGravityPlane(TargetWorldDir) * HorizontalShiftFromTarget;
end;

procedure TCastleThirdPersonNavigation.Init;
var
  GravUp: TVector3;
  A: TCastleTransform;
  CameraPos, CameraDir, CameraUp, TargetWorldPosForward: TVector3;
begin
  A := RealAvatarHierarchy;
  if (A <> nil) and (InternalViewport <> nil) then
  begin
    TargetWorldPosForward := A.WorldTransform.MultPoint(AvatarTargetForward);
    GravUp := Camera.GravityUp;

    CameraPos := CameraPositionInitial(A);
    { We know that AvatarTargetForward influence on direction is 100%,
      AvatarTarget is 0%,
      since camera is positioned precisely at the back of avatar. }
    CameraDir := TargetWorldPosForward - CameraPos;
    CameraUp := GravUp; // will be adjusted to be orthogonal to Dir by SetView
    Camera.SetView(CameraPos, CameraDir, CameraUp);

    if Avatar <> nil then
    begin
      Avatar.PlayAnimation('idle', true);
      Avatar.ForceInitialAnimationPose;
    end;
  end;

  MouseLook := true; // always use mouse look
end;

procedure TCastleThirdPersonNavigation.ProcessMouseLookDelta(const Delta: TVector2);
var
  ToCamera, GravUp: TVector3;
  A: TCastleTransform;

  { Change ToCamera by applying DeltaY from mouse look. }
  procedure ProcessVertical(DeltaY: Single);
  const
    { Do not allow to look exactly up or exactly down,
      as then further vertical moves would be undefined,
      so you would not be able to "get out" of such rotation. }
    MinimalAngleFromZenith = 0.1;
  var
    Side: TVector3;
    AngleToUp, AngleToDown, MaxChange: Single;
  begin
    Side := TVector3.CrossProduct(ToCamera, GravUp);
    if DeltaY > 0 then
    begin
      AngleToUp := AngleRadBetweenVectors(ToCamera, GravUp);
      MaxChange := Max(0, AngleToUp - MinimalAngleFromZenith);
      if DeltaY > MaxChange then
        DeltaY := MaxChange;
    end else
    begin
      AngleToDown := AngleRadBetweenVectors(ToCamera, -GravUp);
      MaxChange := Max(0, AngleToDown - MinimalAngleFromZenith);
      if DeltaY < -MaxChange then
        DeltaY := -MaxChange;
    end;
    ToCamera := RotatePointAroundAxisRad(DeltaY, ToCamera, Side);
  end;

  procedure ProcessHorizontal(const DeltaX: Single);
  begin
    ToCamera := RotatePointAroundAxisRad(DeltaX, ToCamera, GravUp);
  end;

  function ForwardInfluence(const TargetWorldPos, CameraPos: TVector3): Single;
  // TODO: expose as properties
  const
    AngleForward = 0.05;
    AngleNonForward = 0.5;
  var
    Angle: Single;
  begin
    Angle := AngleRadBetweenVectors(
      CameraPos - TargetWorldPos,
      CameraPositionInitial(A) - TargetWorldPos);
    Result := MapRangeClamped(Angle, AngleForward, AngleNonForward, 1, 0);
  end;

var
  CameraPos, CameraDir, CameraUp,
    TargetWorldPos, TargetWorldPosForward, LookTarget: TVector3;
begin
  inherited;
  A := RealAvatarHierarchy;
  if (A <> nil) and (InternalViewport <> nil) then
  begin
    TargetWorldPos := A.WorldTransform.MultPoint(AvatarTarget);
    TargetWorldPosForward := A.WorldTransform.MultPoint(AvatarTargetForward);
    ToCamera := Camera.Position - TargetWorldPos;
    GravUp := Camera.GravityUp;

    ProcessVertical(Delta[1]);
    ProcessHorizontal(Delta[0]);

    // TODO: check collisions
    CameraPos := TargetWorldPos + ToCamera;

    LookTarget := Lerp(SmoothStep(0, 1, ForwardInfluence(TargetWorldPos, CameraPos)),
      TargetWorldPos, TargetWorldPosForward);
    CameraDir := LookTarget - CameraPos;
    CameraUp := GravUp; // will be adjusted to be orthogonal to Dir by SetView
    Camera.SetView(CameraPos, CameraDir, CameraUp);
  end;
end;

procedure TCastleThirdPersonNavigation.Update(const SecondsPassed: Single;
  var HandleInput: boolean);
begin
  inherited;
end;


(*TODO:

  - on mouse wheel, decrease / increase DistanceToAvatarTarget within some bounds
    (MinDistanceToAvatarTarget, MaxDistanceToAvatarTarget, default
     DefaultMinDistanceToAvatarTarget, DefaultMaxDistanceToAvatarTarget
     0.1
     10)

    this immediately moves camera

  - AWSD moves charaters left / right / forward / back (in avatar space,
    looking at avatar Direction and Up)

    changes animation too

  - in demo:
    expose AimAvatar
    describe keys in label

  - document / show a way to use this with TPlayer and TLevel

  - are my controls inverted? compare with other games.
*)

{ TStatePlay ----------------------------------------------------------------- }

procedure TStatePlay.Start;
var
  UiOwner: TComponent;
  SoldierScene: TCastleScene;
  Enemy: TEnemy;
  I: Integer;
begin
  inherited;

  { Load designed user interface }
  InsertUserInterface('castle-data:/state_play.castle-user-interface', FreeAtStop, UiOwner);

  { Find components, by name, that we need to access from code }
  LabelFps := UiOwner.FindRequiredComponent('LabelFps') as TCastleLabel;
  MainViewport := UiOwner.FindRequiredComponent('MainViewport') as TCastleViewport;
  SceneAvatar := UiOwner.FindRequiredComponent('SceneAvatar') as TCastleScene;

  { Create TEnemy instances, add them to Enemies list }
  Enemies := TEnemyList.Create(true);
  for I := 1 to 4 do
  begin
    SoldierScene := UiOwner.FindRequiredComponent('SceneSoldier' + IntToStr(I)) as TCastleScene;
    Enemy := TEnemy.Create(SoldierScene);
    Enemies.Add(Enemy);
  end;

  { Initialize 3rd-person camera initialization }
  ThirdPersonNavigation := TCastleThirdPersonNavigation.Create(FreeAtStop);
  MainViewport.Navigation := ThirdPersonNavigation;
  ThirdPersonNavigation.Avatar := SceneAvatar;
  { TODO: remove AvatarTargetForward idea completely?
    It breaks the feeling of control over the camera. }
  // ThirdPersonNavigation.AvatarTargetForward := Vector3(0, 2, 4);
  ThirdPersonNavigation.Init;
end;

procedure TStatePlay.Stop;
begin
  FreeAndNil(Enemies);
  inherited;
end;

procedure TStatePlay.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  { This virtual method is executed every frame.}
  LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;
end;

function TStatePlay.Press(const Event: TInputPressRelease): Boolean;
var
  HitEnemy: TEnemy;
begin
  Result := inherited;
  if Result then Exit; // allow the ancestor to handle keys

  { This virtual method is executed when user presses
    a key, a mouse button, or touches a touch-screen.

    Note that each UI control has also events like OnPress and OnClick.
    These events can be used to handle the "press", if it should do something
    specific when used in that UI control.
    The TStatePlay.Press method should be used to handle keys
    not handled in children controls.
  }

  if Event.IsMouseButton(mbLeft) then
  begin
    SoundEngine.Sound(SoundEngine.SoundFromName('shoot_sound'));

    { We clicked on enemy if
      - TransformUnderMouse indicates we hit something
      - This something has, as 1st child, a TEnemy instance.

      We depend here on our TEnemy behaviour:
      - TEnemy instance adds itself as child of TCastleScene
      - TEnemy has no collidable things by itself, so it's not listed among MouseRayHit.
    }
    if (MainViewport.TransformUnderMouse <> nil) and
       (MainViewport.TransformUnderMouse.Count > 0) and
       (MainViewport.TransformUnderMouse.Items[0] is TEnemy) then
    begin
      HitEnemy := MainViewport.TransformUnderMouse.Items[0] as TEnemy;
      HitEnemy.Hurt;
    end;

    Exit(true);
  end;

  if Event.IsKey(keyF5) then
  begin
    Container.SaveScreenToDefaultFile;
    Exit(true);
  end;

  if Event.IsKey(keyEscape) then
  begin
    TUIState.Current := StateMenu;
    Exit(true);
  end;
end;

end.