{
  Copyright 2008-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Save routines, common for both XML and classic encoding. }

{$ifdef read_interface}

{ Which VRML/X3D version should be used to save this 3D model. }
function Save3DVersion(Node: TX3DNode): TX3DVersion;

{ Write VRML/X3D model to a file.
  Generates a complete file, with header lines (XML headers,
  or #VRML / #X3D in classic encoding) and everything.

  Overloaded version that takes an URL will automatically compress
  the file with gzip if an extension indicating gzip compression is present
  (like .x3dv.gz, or .x3d.gz).

  Generator and Source, if not empty, will be used to set appropriate
  META values of X3D root file node. This way you can indicate inside X3D file
  the generator (your program) name and source (original 3D model file name).
  If this is not an X3D root file node, we will record it inside a comment.

  @bold(Conversion to X3D:)

  When ForceConvertingToX3D or when Encoding <> xeClassic,
  the node graph will be converted to X3D (if it isn't X3D already).
  This can be used to convert VRML 2.0 to X3D.

  This should not be used if the original file version (recorded in Node)
  indicates that it's an old VRML 1.0 or Inventor file,
  as we have not implemented convertion from VRML 1.0/Inventor to X3D.
  So it wil result in VRML 1.0/Inventor nodes saved using
  the X3D (XML or classic) encoding, which is not a format supported
  by any X3D reader (even our own).

  Note that converting VRML 2.0 to X3D will change the nodes graph in-place,
  possibly removing some nodes. If you use TCastleSceneCore, you should call
  @link(TCastleSceneCore.BeforeNodesFree) before such operation,
  and @link(TCastleSceneCore.ChangedAll) afterwards.
  (You can easily test whether they will be needed by
  @link(Save3DWillConvertToX3D)).

  If you use Encoding=xeClassic and ForceConvertingToX3D=false,
  no conversion will ever happen.

  @param(Version Which VRML/X3D specification version should be used
    to encode. It should be calculated by Save3DVersion(Node).
    You often want to calculate it yourself, before calling Save3D,
    this way you can propose a sensible saved model extension for user
    (.wrl for VRML <= 2.0 in classic encoding, .x3dv for X3D in classic encoding).

    Note that @italic(this parameter is @bold(not) a mechanism to convert
    between various VRML/X3D versions). This procedure does not convert VRML/X3D
    nodes/fields inside. For example, you can't just change Version.Major value
    from 1 to 3 to convert VRML 1.0 to X3D.
    It would cause some information to be encoded in X3D style
    (e.g. generated file will have X3D header and PROFILE information),
    but the nodes would stil have VRML 1.0 names and fields.
    Which means that you would not generate correct X3D file.

    So this should really be calculated based on model contents,
    usually by Save3DVersion(Node).

    A limited VRML 2.0 conversion is possible by ForceConvertingToX3D = true.
    In this case, Version will be automatically changed to X3D anyway.)

  @groupBegin }
procedure Save3D(Node: TX3DNode;
  const Stream: TStream; const Generator, Source: string;
  Version: TX3DVersion; const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean = false); overload; deprecated 'use SaveNode';
procedure Save3D(Node: TX3DNode;
  const URL, Generator, Source: string;
  const Version: TX3DVersion; const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean = false); overload; deprecated 'use SaveNode';
procedure Save3D(Node: TX3DNode;
  const Stream: TStream; const Generator, Source: string;
  const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean = false); overload; deprecated 'use SaveNode';
procedure Save3D(Node: TX3DNode;
  const URL, Generator, Source: string;
  const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean = false); overload; deprecated 'use SaveNode';
procedure Save3D(Node: TX3DNode;
  const URL: string;
  const Generator: string = '';
  const Source: string = ''); overload; deprecated 'use SaveNode';
{ @groupEnd }

function Save3DWillConvertToX3D(Version: TX3DVersion;
  const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean): boolean;

{$endif read_interface}

{$ifdef read_implementation}

type
  { TX3DWriter extended with NodeNames. }
  TX3DWriterNames = class(TX3DWriter)
    { Record known node names.
      This allows to write correct DEF / USE when saving. }
    NodeNames: TX3DNodeNames;

    constructor Create(AStream: TStream;
      const AVersion: TX3DVersion; const AEncoding: TX3DEncoding);
    destructor Destroy; override;
  end;

constructor TX3DWriterNames.Create(AStream: TStream;
  const AVersion: TX3DVersion; const AEncoding: TX3DEncoding);
begin
  inherited;
  NodeNames := TX3DNodeNames.Create(false);
end;

destructor TX3DWriterNames.Destroy;
begin
  FreeAndNil(NodeNames);
  inherited;
end;

const
  { Used when we have to save as X3D, but profile information is missing. }
  DefaultX3DSaveProfile = 'Interchange';

function Save3DVersion(Node: TX3DNode): TX3DVersion;
begin
  if (Node is TX3DRootNode) and
     TX3DRootNode(Node).HasForceVersion then
    Result := TX3DRootNode(Node).ForceVersion else
    { Use latest X3D. We should promote latest, best version of VRML/X3D.
      Also, this avoids conversion to X3D when saving it to XML encoding. }
    Result := X3DVersion;
end;

{ TVRMLToX3DConverter -------------------------------------------------------- }

type
  TVRMLToX3DConverter = class
    procedure Convert(ParentNode: TX3DNode; var Node: TX3DNode);
  end;

procedure TVRMLToX3DConverter.Convert(ParentNode: TX3DNode; var Node: TX3DNode);

  function CoordinateNode(Coords: TMFVec3f): TCoordinateNode;
  begin
    Result := TCoordinateNode.Create('', Node.BaseUrl);
    Result.FdPoint.AssignValue(Coords);
  end;

  function ConvertNurbsCurve(Node: TNurbsCurveNode_2): TNurbsCurveNode;
  begin
    Result := TNurbsCurveNode.Create(Node.X3DName, Node.BaseUrl);
    Result.PositionInParent := Node.PositionInParent;

    Result.FdcontrolPoint.Value := CoordinateNode(Node.FdcontrolPoint);
    Result.Fdweight.Items.Assign(Node.FdWeight.Items); { converts float to double }
    Result.Fdtessellation.AssignValue(Node.Fdtessellation);
    Result.Fdknot.Items.Assign(Node.Fdknot.Items); { converts float to double }
    Result.Fdorder.AssignValue(Node.Fdorder);
    Result.FdClosed.Value := true; { true means "possibly closed" }
  end;

  function ConvertNurbsSurface(Node: TNurbsSurfaceNode): TNurbsPatchSurfaceNode;
  begin
    Result := TNurbsPatchSurfaceNode.Create(Node.X3DName, Node.BaseUrl);
    Result.PositionInParent := Node.PositionInParent;

    Result.FdcontrolPoint.Value := CoordinateNode(Node.FdcontrolPoint);
    Result.FdtexCoord.AssignValue(Node.FdtexCoord);
    Result.FduTessellation.AssignValue(Node.FduTessellation);
    Result.FdvTessellation.AssignValue(Node.FdvTessellation);
    Result.Fdweight.Items.Assign(Node.FdWeight.Items); { converts float to double }
    Result.FdSolid.AssignValue(Node.FdSolid);

    Result.FdUClosed.Value := true; { true means "possibly closed" }
    Result.FdUDimension.AssignValue(Node.FdUDimension);
    Result.FdUKnot.Items.Assign(Node.FdUknot.Items); { converts float to double }
    Result.FdUOrder.AssignValue(Node.FdUorder);

    Result.FdVClosed.Value := true; { true means "possibly closed" }
    Result.FdVDimension.AssignValue(Node.FdVDimension);
    Result.FdVKnot.Items.Assign(Node.FdVKnot.Items); { converts float to double }
    Result.FdVOrder.AssignValue(Node.FdVOrder);
  end;

  function ConvertNurbsPositionInterpolator(Node: TNurbsPositionInterpolatorNode_2): TNurbsPositionInterpolatorNode;
  begin
    Result := TNurbsPositionInterpolatorNode.Create(Node.X3DName, Node.BaseUrl);
    Result.PositionInParent := Node.PositionInParent;

    Result.FdcontrolPoint.Value := CoordinateNode(Node.FdKeyValue);
    Result.Fdknot.Items.Assign(Node.Fdknot.Items); { converts float to double }
    Result.Fdorder.AssignValue(Node.Fdorder);
    Result.Fdweight.Items.Assign(Node.FdKeyWeight.Items); { converts float to double }
  end;

begin
  { The nodes needing to be converted from VRML 2.0 to X3D:
    - Some can be found by grepping for "Version.Major = 2".
      This will find which nodes have ForVRMLVersion method requiring
      only VRML 2.0. These are only:
      TLODNode_2, TNurbsCurveNode_2, TNurbsPositionInterpolatorNode_2.
    - TLODNode_2 doesn't actually need conversion. Only a field name
      changes, which should be taken care of NameForVersion mechanism.
    - TNurbsSurfaceNode needs additionally to be changed in
      TNurbsPatchSurfaceNode.

    NURBS differences are summarized in
    https://castle-engine.io/x3d_implementation_nurbs.php#section_vrml2_support

    TODO: this simple replacement will not work for cases when:
    - you have ROUTEs leading to old nodes (ROUTEs will become disconnected
      when destroying old nodes)
    - you rely of reUSEing old nodes (in new version, we will have new node
      for each previous reference).
    - If you declare your VRML 2 nurbs nodes by EXTERNPROTO
      (like White Dune does) e.g. by "urn:web3d:vrml97:node:NurbsCurve"
      we *will* convert your NurbsCurve,
      but we will not remove (or modify) the EXTERNPROTO.
      If you save to classic encoding, this will cause problems,
      as when reading we will see EXTERNPROTO and try to read VRML 2 version
      of the node.
      If you save to XML encoding, this is avoided, as then we have
      <NurbsCurve> instead of <ProtoInstance name="NurbsCurve">,
      and the invalid externproto is not relevant.
  }
  {$warnings off} // supporting deprecated nodes
  if Node is TNurbsCurveNode_2 then
    Node := ConvertNurbsCurve(TNurbsCurveNode_2(Node)) else
  if Node is TNurbsSurfaceNode then
    Node := ConvertNurbsSurface(TNurbsSurfaceNode(Node)) else
  if Node is TNurbsPositionInterpolatorNode_2 then
    Node := ConvertNurbsPositionInterpolator(TNurbsPositionInterpolatorNode_2(Node));
  {$warnings on}
end;

{ TFixNamesHandler ----------------------------------------------------------- }

type
  TFixNamesHandler = class
  strict private
    Visited: TList;
    Names: TCastleStringList;
  public
    constructor Create;
    destructor Destroy; override;
    function HandleNode(ParentNode, Node: TX3DNode): Pointer;
  end;

constructor TFixNamesHandler.Create;
begin
  inherited;
  Names := TCastleStringList.Create;
  Names.CaseSensitive := true;
  Visited := TList.Create;
end;

destructor TFixNamesHandler.Destroy;
begin
  FreeAndNil(Names);
  FreeAndNil(Visited);
  inherited;
end;

function TFixNamesHandler.HandleNode(ParentNode, Node: TX3DNode): Pointer;

  { Change Node.X3DName to something not yet existing in Names.
    This knows that Node.X3DName is <> '' and it exists in Names,
    IOW on entry the Node is named, and the name is not unique. }
  procedure RenameUniquely(const Node: TX3DNode);

    procedure RenameUniquelyCore(const Node: TX3DNode; const Prefix: String; NextNumber: Int64);
    begin
      while Names.IndexOf(Prefix + IntToStr(NextNumber)) <> -1 do
        Inc(NextNumber);
      Node.X3DName := Prefix + IntToStr(NextNumber);
    end;

  var
    I: Integer;
    Number: Int64;
  begin
    I := BackPos('_', Node.X3DName);
    if I <> 0 then
    begin
      Number := StrToIntDef(SEnding(Node.X3DName, I + 1), -1);
      if Number >= 0 then
        RenameUniquelyCore(Node, Copy(Node.X3DName, 1, I - 1), Number + 1)
      else
        RenameUniquelyCore(Node, Node.X3DName + '_', 2);
    end else
      RenameUniquelyCore(Node, Node.X3DName + '_', 2);
  end;

  { Assuming Node.X3DName <> '', make sure it is unique name. }
  procedure MakeUniquelyNamed(const Node: TX3DNode);
  var
    I: Integer;
  begin
    I := Names.IndexOf(Node.X3DName);
    if I = - 1 then
    begin
      // new name
      Names.AddObject(Node.X3DName, Node);
    end else
    if Names.Objects[I] <> Node then
    begin
      // name already taken by a different node
      RenameUniquely(Node);
      Names.AddObject(Node.X3DName, Node);
    end;
  end;

  { Make sure Node has a non-empty name, and unique name.
    Given Node may be nil (it is ignored then). }
  procedure MakeNamed(const Node: TX3DNode);
  begin
    if (Node <> nil) and (Node.X3DName = '') then
    begin
      Node.X3DName := Node.X3DType;
      if Node.X3DName = '' then
        Node.X3DName := 'Node';
      MakeUniquelyNamed(Node);
    end;
  end;

var
  Route: TX3DRoute;
  I: Integer;
begin
  Result := nil;

  { early exit if this node was already visited,
    to save time when traversing graph with DEF/USE. }
  if Visited.IndexOf(Node) <> -1 then
    Exit;
  Visited.Add(Node);

  { make sure node name is unique }
  if Node.X3DName <> '' then
    MakeUniquelyNamed(Node);

  { make sure nodes used in ROUTEs and uniquely named }
  for I := 0 to Node.RoutesCount - 1 do
  begin
    Route := Node.Routes[I];
    MakeNamed(Route.SourceNode);
    MakeNamed(Route.DestinationNode);
  end;

  { recursively check children }
  Node.DirectEnumerateAll({$ifdef FPC}@{$endif} Self.HandleNode);
end;

{ global routines ------------------------------------------------------------ }

function Save3DWillConvertToX3D(Version: TX3DVersion;
  const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean): boolean;
begin
  Result := (Version.Major < 3) and
    (ForceConvertingToX3D or (Encoding <> xeClassic));
end;

procedure Save3D(Node: TX3DNode;
  const Stream: TStream; const Generator, Source: string;
  Version: TX3DVersion;
  const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean);
var
  Writer: TX3DWriterNames;

  procedure FixNames;
  var
    Handler: TFixNamesHandler;
  begin
    Handler := TFixNamesHandler.Create;
    try
      Handler.HandleNode(nil, Node);
      Node.DirectEnumerateAll({$ifdef FPC}@{$endif} Handler.HandleNode);
    finally FreeAndNil(Handler) end;
  end;

  procedure ConvertToX3D;
  begin
    { Converts VRML (1, 2) to X3D simply by changing Version used to save.
      This will work fine for VRML 2 -> X3D (except for some NURBS nodes
      different between VRML 2 and X3D, these will be dealt with TVRMLToX3DConverter).
      This will not really work for VRML 1. }
    if Version.Major <= 1 then
      WritelnWarning('VRML/X3D', 'Converting VRML 1.0 or Inventor to X3D is not implemented. You will get VRML 1.0/Inventor nodes encoded like for X3D, which probably is not much useful.');
    Version.Major := 3;
    Version.Minor := 0;

    { Since we convert in-place (replacing nodes inside),
      then Node must be a TX3DRootNode to replace in it the version.
      Fortunately, our Save3DVersion already guarantees it:
      if a node isn't TX3DRootNode, it's always treated as X3D already,
      so a conversion will not happen. }
    Assert(Node is TX3DRootNode, 'Nodes must be TX3DRootNode to convert to X3D, to mark new version.');
    (Node as TX3DRootNode).HasForceVersion := true;
    (Node as TX3DRootNode).ForceVersion := Version;

    Node.EnumerateReplaceChildren({$ifdef FPC}@{$endif} TVRMLToX3DConverter(nil).Convert);
  end;

  procedure Classic;

    procedure SaveProfile(Root: TX3DRootNode);
    begin
      if Root.Profile <> '' then
        Writer.Writeln('PROFILE ' + Root.Profile + NL) else
        Writer.Writeln('PROFILE ' + DefaultX3DSaveProfile + NL);
    end;

    procedure SaveComponents(Root: TX3DRootNode);
    var
      ComponentLevel: {$ifdef FPC}TStringLongIntMap.TDictionaryPair{$else}TPair<string, LongInt>{$endif};
    begin
      for ComponentLevel in Root.Components do
        Writer.Writeln(Format('COMPONENT %s:%d',
          [ ComponentLevel.Key,
            ComponentLevel.Value ]));
      if Root.Components.Count <> 0 then
        Writer.Write(NL);
    end;

    procedure SaveMetas(Root: TX3DRootNode);
    var
      MetaPair: {$ifdef FPC}TStringStringMap.TDictionaryPair{$else}TPair<string, string>{$endif};
    begin
      for MetaPair in Root.Meta do
        Writer.Writeln(Format('META %s %s',
          [ StringToX3DClassic(MetaPair.Key),
            StringToX3DClassic(MetaPair.Value)]));
      if Root.Meta.Count <> 0 then
        Writer.Write(NL);
    end;

  const
    VRML10Header = '#VRML V1.0 ascii';
    VRML20Header = '#VRML V2.0 utf8';
    X3DHeader = '#X3D V%d.%d utf8';
  var
    VRMLHeader, PrecedingComment: string;
  begin
    if Version.Major <= 1 then
      VRMLHeader := VRML10Header else
    if Version.Major = 2 then
      VRMLHeader := VRML20Header else
    if Version.Major >= 3 then
      VRMLHeader := Format(X3DHeader, [Version.Major, Version.Minor]);

    Writer.Writeln(VRMLHeader + NL { yes, one more NL, to look good });

    if (Version.Major >= 3) and (Node is TX3DRootNode) then
    begin
      if Generator <> '' then
        TX3DRootNode(Node).Meta.PutPreserve('generator', Generator);
      if Source <> '' then
        TX3DRootNode(Node).Meta.PutPreserve('source', Source);
      SaveProfile(TX3DRootNode(Node));
      SaveComponents(TX3DRootNode(Node));
      SaveMetas(TX3DRootNode(Node));
    end else
    if Version.Major >= 3 then
    begin
      { X3D, but no TX3DRootNode. Use default X3D profile. }
      Writer.Writeln('PROFILE ' + DefaultX3DSaveProfile);
      if Generator <> '' then
        Writer.Writeln(Format('META %s %s',
          [ StringToX3DClassic('generator'),
            StringToX3DClassic(Generator)]));
      if Source <> '' then
        Writer.Writeln(Format('META %s %s',
          [ StringToX3DClassic('source'),
            StringToX3DClassic(Source)]));
      Writer.Writeln;
    end else
    if (Generator <> '') or (Source <> '') then
    begin
      { write Generator and Source as comment }
      PrecedingComment := '';
      if Generator <> '' then
        PrecedingComment := PrecedingComment + ('# Generated by ' + SReplaceChars(Generator, [#10, #13], ' ') + NL);
      if Source <> '' then
        PrecedingComment := PrecedingComment + ('# Source model: ' + SReplaceChars(Source, [#10, #13], ' ') + NL);
      Writer.Writeln(PrecedingComment);
    end;

    { Node may be TX3DRootNode here, that's OK,
      TX3DRootNode.SaveToStream will magically handle this right. }
    Node.SaveToStream(Writer);
  end;

  procedure Xml;

    function Profile: string;
    begin
      if (Node is TX3DRootNode) and
         (TX3DRootNode(Node).Profile <> '') then
        Result := TX3DRootNode(Node).Profile else
        Result := DefaultX3DSaveProfile;
    end;

    procedure SaveComponents(Root: TX3DRootNode);
    var
      ComponentLevel: {$ifdef FPC}TStringLongIntMap.TDictionaryPair{$else}TPair<string, LongInt>{$endif};
    begin
      for ComponentLevel in Root.Components do
        Writer.WritelnIndent(Format('<component name=%s level="%d" />',
          [ StringToX3DXml(ComponentLevel.Key),
            ComponentLevel.Value ]));
    end;

    procedure SaveMetas(Root: TX3DRootNode);
    var
      MetaPair: {$ifdef FPC}TStringStringMap.TDictionaryPair{$else}TPair<string, string>{$endif};
    begin
      for MetaPair in Root.Meta do
        Writer.WritelnIndent(Format('<meta name=%s content=%s />',
          [ StringToX3DXml(MetaPair.Key),
            StringToX3DXml(MetaPair.Value)]));
    end;

  begin
    Writer.Writeln(Format(
      '<?xml version="1.0" encoding="UTF-8"?>' + NL +
      '<!DOCTYPE X3D PUBLIC "ISO//Web3D//DTD X3D %d.%d//EN" "http://www.web3d.org/specifications/x3d-%0:d.%1:d.dtd">' + NL+
      '<X3D profile=%2:s version="%0:d.%1:d"' + NL+
      '     xmlns:xsd="http://www.w3.org/2001/XMLSchema-instance"' + NL+
      '     xsd:noNamespaceSchemaLocation="http://www.web3d.org/specifications/x3d-%0:d.%1:d.xsd">' + NL+
      '<head>',
      [Version.Major, Version.Minor, StringToX3DXml(Profile)]));
    Writer.IncIndent;

    if Node is TX3DRootNode then
    begin
      if Generator <> '' then
        TX3DRootNode(Node).Meta.PutPreserve('generator', Generator);
      if Source <> '' then
        TX3DRootNode(Node).Meta.PutPreserve('source', Source);
      SaveComponents(TX3DRootNode(Node));
      SaveMetas(TX3DRootNode(Node));
    end else
    begin
      { write Generator etc. directly, as we don't have TX3DRootNode.Meta available }
      if Generator <> '' then
        Writer.WritelnIndent(Format('<meta name="generator" content=%s />',
          [StringToX3DXml(Generator)]));
      if Source <> '' then
        Writer.WritelnIndent(Format('<meta name="source" content=%s />',
          [StringToX3DXml(Source)]));
    end;

    Writer.DecIndent;
    Writer.Writeln('</head>' + NL + '<Scene>');

    { Node may be TX3DRootNode here, that's OK,
      TX3DRootNode.SaveToStream will magically handle this right. }
    Writer.IncIndent;
    Node.SaveToStream(Writer);
    Writer.DecIndent;

    Writer.Writeln('</Scene>' +NL + '</X3D>');
  end;

begin
  if Save3DWillConvertToX3D(Version, Encoding, ForceConvertingToX3D) then
    ConvertToX3D;

  FixNames;

  Writer := TX3DWriterNames.Create(Stream, Version, Encoding);
  try
    case Encoding of
      xeClassic: Classic;
      xeXML:     Xml;
      {$ifndef COMPILER_CASE_ANALYSIS}
      else raise EInternalError.Create('Saving Encoding?');
      {$endif}
    end;
  finally FreeAndNil(Writer) end;
end;

procedure Save3D(Node: TX3DNode;
  const URL, Generator, Source: string; const Version: TX3DVersion;
  const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean);
var
  Stream: TStream;
  Gzipped: boolean;
  StreamOptions: TSaveStreamOptions;
begin
  { calculate StreamOptions to include gzip compression when necessary }
  StreamOptions := [];
  URIMimeType(URL, Gzipped);
  if Gzipped then
    Include(StreamOptions, ssoGzip);

  Stream := URLSaveStream(URL, StreamOptions);
  try
    {$warnings off} // using deprecated in deprecated
    Save3D(Node, Stream, Generator, Source, Version,
      Encoding, ForceConvertingToX3D);
    {$warnings on}
  finally Stream.Free end;
end;

procedure Save3D(Node: TX3DNode;
  const Stream: TStream; const Generator, Source: string;
  const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean);
begin
  {$warnings off} // using deprecated in deprecated
  Save3D(Node, Stream, Generator, Source, Save3DVersion(Node),
    Encoding, ForceConvertingToX3D);
  {$warnings on}
end;

procedure Save3D(Node: TX3DNode;
  const URL, Generator, Source: string;
  const Encoding: TX3DEncoding;
  const ForceConvertingToX3D: boolean);
begin
  {$warnings off} // using deprecated in deprecated
  Save3D(Node, URL, Generator, Source, Save3DVersion(Node),
    Encoding, ForceConvertingToX3D);
  {$warnings on}
end;

procedure Save3D(Node: TX3DNode;
  const URL: string;
  const Generator: string = '';
  const Source: string = '');
var
  Mime: string;
  Encoding: TX3DEncoding;
begin
  { guess Encoding from URL }
  Mime := URIMimeType(URL);
  if (Mime = 'model/vrml') or
     (Mime = 'model/x3d+vrml') then
    Encoding := xeClassic else
    Encoding := xeXML;
  {$warnings off} // using deprecated in deprecated
  Save3D(Node, URL, Generator, Source, Encoding);
  {$warnings on}
end;

{$endif read_implementation}