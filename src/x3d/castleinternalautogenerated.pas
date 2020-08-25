{
  Copyright 2018-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Information about auto-generated resources (TAutoGenerated). }
unit CastleInternalAutoGenerated;

{$I castleconf.inc}

interface

uses Generics.Collections, DOM,
  CastleImages, CastleUtils;

type
  { Information about auto-generated resources, right now: auto-generated
    compressed and downscaled textures.
    See https://castle-engine.io/creating_data_auto_generated_textures.php .
    This information is read and written by the CGE build tool.
    It may also be accessed during the game by the engine, automatically
    (e.g. by CastleMaterialProperties). }
  TAutoGenerated = class
  public
    type
      TGeneratedTexture = class
        { URL of the texture.
          Relative to the CastleAutoGenerated.xml file,
          which also always means: relative to the game data directory. }
        Url: string;

        Compressed: Boolean;
        Compression: TTextureCompression; //< only relevant if Compressed
        Scale: Cardinal;

        { Platforms for which this is created and used.
          If the current @link(Platform) isn't included in this set,
          then the file may not exist, because "castle-engine package"
          could exclude it from distributing for this platform. }
        Platforms: TCastlePlatforms;

        procedure Save(const ParentElement: TDOMElement);
        procedure Load(const E: TDOMElement);
      end;

      TGeneratedTextureList = {$ifdef CASTLE_OBJFPC}specialize{$endif} TObjectList<TGeneratedTexture>;

      TTexture = class
      private
        { Generated output files for this texture. }
        FGenerated: TGeneratedTextureList;
      public
        { URL of the texture.
          Relative to the CastleAutoGenerated.xml file,
          which also always means: relative to the game data directory. }
        Url: string;

        { The hash associated with each resource URL,
          used to detect whether the auto-generated things need updating. }
        Hash: string;

        { Dimensions of the texture, just like for TCastleImage.

          These are dimensions before eventual downscaling (downscaling which may be requested
          by data/material_properties.xml and done by "castle-engine auto-generate-texture",
          see https://castle-engine.io/creating_data_auto_generated_textures.php ). }
        Width, Height, Depth: Cardinal;

        constructor Create;
        destructor Destroy; override;

        { Creates a new TGeneratedTexture for this compression and scale, if necessary. }
        function Generated(const Compressed: Boolean; const Compression: TTextureCompression;
          const Scale: Cardinal): TGeneratedTexture;
        procedure Save(const ParentElement: TDOMElement);
        procedure Load(const E: TDOMElement);
      end;
  private
    type
      TTextureList = {$ifdef CASTLE_OBJFPC}specialize{$endif} TObjectList<TTexture>;
    var
      Textures: TTextureList;
  public
    const
      FileName = 'CastleAutoGenerated.xml';
      AutoGeneratedDirName = 'auto_generated';

    constructor Create;
    destructor Destroy; override;

    { Load information from CastleAutoGenerated.xml file.
      Loading non-existing URL is allowed and ignored
      (it is equivalent to loading an empty file, so it will clear current knowledge). }
    procedure LoadFromFile(const Url: string);
    procedure SaveToFile(const Url: string);

    { Remove the entries for no longer existing input files.
      TODO: In the future, it should also remove the auto-generated output
      for the no-longer-existing input files. }
    procedure CleanNotExisting(const ProjectDataUrl: string; const Verbose: boolean);

    { Get existing, or create new, Texture for this Url.

      Given Url must be relative to the data directory.
      Inside CastleAutoGenerated.xml we only store information about files
      in the data directory.
      If necessary use @link(RelativeToCastleDataURL) to transform it. }
    function Texture(const Url: string; const CreateIfNotExists: Boolean): TTexture;

    { According to the CastleAutoGenerated.xml information, should the given data file
      be distrubuted for given platform?  }
    function IncludeDataForPlatform(const TargetPlatform: TCastlePlatform;
      const UrlInData: String): Boolean;

    { Is file at given URL used by the auto-generated mechanism.
      Given Url must be relative to the data directory. }
    function Used(const Url: string): Boolean;
  end;

implementation

uses SysUtils,
  CastleXMLUtils, CastleURIUtils, CastleStringUtils;

function PlatformsToStr(const Platforms: TCastlePlatforms): String;
var
  P: TCastlePlatform;
begin
  { Special result when all plaforms are included.
    This way when adding new platforms in the future,
    they'll automatically be part of this. }
  if Platforms = AllPlatforms then
    Exit('all');

  Result := '';
  for P in Platforms do
    Result := SAppendPart(Result, ';', PlatformToStr(P));
end;

function StrToPlatforms(const S: String): TCastlePlatforms;
var
  PlatformsStr: TCastleStringList;
  PlatformStr: String;
begin
  if S = 'all' then
    Exit(AllPlatforms);

  Result := [];
  PlatformsStr := SplitString(S, ';');
  try
    for PlatformStr in PlatformsStr do
      Include(Result, StrToPlatform(PlatformStr));
  finally FreeAndNil(PlatformsStr) end;
end;

{ TAutoGenerated.TGeneratedTexture ------------------------------------------- }

procedure TAutoGenerated.TGeneratedTexture.Save(const ParentElement: TDOMElement);
var
  E: TDOMElement;
begin
  E := ParentElement.CreateChild('generated');
  E.AttributeSet('url', Url);
  E.AttributeSet('compressed', Compressed);
  if Compressed then
    E.AttributeSet('compression', TextureCompressionToString(Compression));
  E.AttributeSet('scale', Scale);
  E.AttributeSet('platforms', PlatformsToStr(Platforms));
end;

procedure TAutoGenerated.TGeneratedTexture.Load(const E: TDOMElement);
begin
  Url := E.AttributeString('url');
  Compressed := E.AttributeBoolean('compressed');
  if Compressed then
    Compression := StringToTextureCompression(E.AttributeString('compression'));
  Scale := E.AttributeCardinal('scale');
  Platforms := StrToPlatforms(E.AttributeString('platforms'));
end;

{ TAutoGenerated.TTexture ---------------------------------------------------- }

constructor TAutoGenerated.TTexture.Create;
begin
  FGenerated := TGeneratedTextureList.Create(true);
  inherited;
end;

destructor TAutoGenerated.TTexture.Destroy;
begin
  FreeAndNil(FGenerated);
  inherited;
end;

procedure TAutoGenerated.TTexture.Save(const ParentElement: TDOMElement);
var
  E: TDOMElement;
  G: TGeneratedTexture;
begin
  E := ParentElement.CreateChild('texture');
  E.AttributeSet('url', Url);
  E.AttributeSet('last_processed_content_hash', Hash);
  E.AttributeSet('width', Width);
  E.AttributeSet('height', Height);
  E.AttributeSet('depth', Depth);

  for G in FGenerated do
    G.Save(E);
end;

procedure TAutoGenerated.TTexture.Load(const E: TDOMElement);
var
  I: TXMLElementIterator;
  G: TGeneratedTexture;
begin
  Url := E.AttributeString('url');
  Hash := E.AttributeString('last_processed_content_hash');
  Width := E.AttributeCardinalDef('width', 0);
  Height := E.AttributeCardinalDef('height', 0);
  Depth := E.AttributeCardinalDef('depth', 0);

  FGenerated.Clear;
  I := E.ChildrenIterator('generated');
  try
    while I.GetNext do
    begin
      G := TGeneratedTexture.Create;
      FGenerated.Add(G);
      G.Load(I.Current);
    end;
  finally FreeAndNil(I) end;
end;

function TAutoGenerated.TTexture.Generated(const Compressed: Boolean; const Compression: TTextureCompression;
  const Scale: Cardinal): TGeneratedTexture;
var
  G: TGeneratedTexture;
begin
  for G in FGenerated do
  begin
    if (G.Compressed = Compressed) and
       (G.Compression = Compression) and
       (G.Scale = Scale) then
      Exit(G);
  end;

  Result := TGeneratedTexture.Create;
  FGenerated.Add(Result);
  Result.Compressed := Compressed;
  Result.Compression := Compression;
  Result.Scale := Scale;
end;

{ TAutoGenerated ------------------------------------------------------------- }

constructor TAutoGenerated.Create;
begin
  inherited;
  Textures := TTextureList.Create;
end;

destructor TAutoGenerated.Destroy;
begin
  FreeAndNil(Textures);
  inherited;
end;

function TAutoGenerated.Texture(const Url: string; const CreateIfNotExists: Boolean): TTexture;
begin
  for Result in Textures do
    if Result.Url = Url then
      Exit;

  if CreateIfNotExists then
  begin
    Result := TTexture.Create;
    Result.Url := Url;
    Textures.Add(Result);
  end else
    Result := nil;
end;

procedure TAutoGenerated.SaveToFile(const Url: string);
var
  Doc: TXMLDocument;
  RootElement, TexturesElement: TDOMElement;
  T: TTexture;
  Comment: TDOMComment;
begin
  Doc := TXMLDocument.Create;
  try
    Comment := Doc.CreateComment(
      'DO NOT EDIT THIS FILE MANUALLY.' + NL +
      'It is automatically created/updated.' + NL +
      NL +
      'This file describes the state of files inside auto_generated' + NL +
      'subdirectories of game data.' + NL +
      'This file should be created and updated only by the Castle Game Engine' + NL +
      'build tool, using commands like "castle-engie auto-generate-textures".' + NL +
      'These commands update things inside auto_generated subdirectories,' + NL +
      '*and* they update the ' + FileName + ' file.' + NL +
      NL +
      'If you transfer the auto_generated subdirectories (e.g. if you commit' + NL +
      'them to the version control repository), then you should also' + NL +
      'transfer (commit) the appropriate ' + FileName + ' file along.' + NL +
      'Otherwise (e.g. if you ignore the auto_generated subdirectories' + NL +
      'in version control), then ignore this file too.' + NL +
      NL +
      'Game code may assume that if some aute-generated files are present,' + NL +
      'then the ''castle-data:/' + FileName + ''' file exists,' + NL +
      'describing them.' + NL);
    Doc.AppendChild(Comment);

    RootElement := Doc.CreateElement('auto_generated');
    Doc.AppendChild(RootElement);

    TexturesElement := RootElement.CreateChild('textures');

    for T in Textures do
      T.Save(TexturesElement);

    URLWriteXML(Doc, Url);
  finally FreeAndNil(Doc) end;
end;

procedure TAutoGenerated.LoadFromFile(const Url: string);
var
  Doc: TXMLDocument;
  T: TTexture;
  I: TXMLElementIterator;
begin
  Textures.Clear;

  { If the file does not exist yet,
    then we have no information about auto-generated resources
    (all last processed Hash is ''), which is OK. }
  if not URIFileExists(Url) then
    Exit;

  Doc := URLReadXML(Url);
  try
    I := Doc.DocumentElement.Child('textures').ChildrenIterator('texture');
    try
      while I.GetNext do
      begin
        T := TTexture.Create;
        Textures.Add(T);
        T.Load(I.Current);
      end;
    finally FreeAndNil(I) end;
  finally FreeAndNil(Doc) end;
end;

procedure TAutoGenerated.CleanNotExisting(const ProjectDataUrl: string;
  const Verbose: boolean);
var
  I: Integer;
  T: TTexture;
  TextureUrl, AutoGeneratedDirUrl: string;
begin
  I := 0;
  while I < Textures.Count do
  begin
    T := Textures[I];
    TextureUrl := CombineURI(ProjectDataUrl, T.Url);
    if not URIFileExists(TextureUrl) then
    begin
      AutoGeneratedDirUrl := ExtractURIPath(TextureUrl) + AutoGeneratedDirName + '/';
      if Verbose then
        Writeln(Format(
          'Texture "%s" no longer exists, removing the record about it from "%s".' + NL +
          'Be sure to also remove the output for this texture inside the "%s" directory (if exists), as we cannot do it automatically now.',
          [TextureUrl, FileName, AutoGeneratedDirUrl]));
      Textures.Delete(I);
    end else
      Inc(I);
  end;
end;

function TAutoGenerated.IncludeDataForPlatform(const TargetPlatform: TCastlePlatform;
  const UrlInData: String): Boolean;
var
  T: TTexture;
  G: TGeneratedTexture;
begin
  { Exclude this file, if it is autogenerated and it is not for TargetPlatform. }
  for T in Textures do
    for G in T.FGenerated do
    begin
      if (G.Url = UrlInData) and (not (TargetPlatform in G.Platforms)) then
        Exit(false);
    end;
  Result := true;
end;

function TAutoGenerated.Used(const Url: string): Boolean;
var
  T: TTexture;
  G: TGeneratedTexture;
begin
  for T in Textures do
  begin
    if T.Url = Url then
      Exit(true);
    for G in T.FGenerated do
      if G.Url = Url then
        Exit(true);
  end;
  Result := false;
end;

end.