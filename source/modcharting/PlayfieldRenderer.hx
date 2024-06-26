package modcharting;

import flixel.tweens.misc.BezierPathTween;
import flixel.tweens.misc.BezierPathNumTween;
import flixel.util.FlxTimer.FlxTimerManager;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import flixel.FlxStrip;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import openfl.geom.Vector3D;
import flixel.util.FlxSpriteUtil;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxSort;

import flixel.FlxG;
import modcharting.Modifier;
import managers.*;
import flixel.system.FlxAssets.FlxShader;
import managers.TweenManager;
import states.PlayState;
import objects.Note;
import objects.StrumArrow;
import objects.Strumline;

using StringTools;

//a few todos im gonna leave here:

//setup quaternions for everything else (incoming angles and the rotate mod)
//do add and remove buttons on stacked events in editor
//fix switching event type in editor so you can actually do set events
//finish setting up tooltips in editor
//start documenting more stuff idk

typedef StrumNoteType = StrumArrow;

class PlayfieldRenderer extends FlxSprite //extending flxsprite just so i can edit draw
{
    public var strumGroup:Strumline;
    public var notes:FlxTypedGroup<Note>;
    public var instance:ModchartMusicBeatState;
    public var playStateInstance:PlayState;
    public var playfields:Array<Playfield> = []; //adding an extra playfield will add 1 for each player

    public var eventManager:ModchartEventManager;
    public var modifierTable:ModTable;
    public var tweenManager:TweenManager = null;
    public var timerManager:FlxTimerManager = null;

    public var modchart:ModchartFile;
    public var inEditor:Bool = false;
    public var editorPaused:Bool = false;

    public var speed:Float = 1.0;

    public var modifiers(get, default):Map<String, Modifier>;

    private function get_modifiers():Map<String, Modifier>
    {
        return modifierTable.modifiers; //back compat with lua modcharts
    }

    public function new(strumGroup:Strumline, notes:FlxTypedGroup<Note>, instance:ModchartMusicBeatState)
    {
        super(0,0);
        this.strumGroup = strumGroup;
        this.notes = notes;
        this.instance = instance;
        if (Std.isOfType(instance, PlayState)) playStateInstance = cast instance; //so it just casts once

        this.strumGroup.visible = false; //drawing with renderer instead
        this.notes.visible = false;

        //fix stupid crash because the renderer in playstate is still technically null at this point and its needed for json loading
        instance.playfieldRenderer = this;

        this.tweenManager = new TweenManager();
        this.timerManager = new FlxTimerManager();
        this.eventManager = new ModchartEventManager(this);
        this.modifierTable = new ModTable(instance, this);
        this.addNewPlayfield(0,0,0);
        this.modchart = new ModchartFile(this);
    }

    public function addNewPlayfield(?x:Float = 0, ?y:Float = 0, ?z:Float = 0, ?alpha:Float = 1)
    {
        this.playfields.push(new Playfield(x,y,z,alpha));
    }

    override function set_camera(cam:FlxCamera):FlxCamera
    {
        if (this.noteCam == null) this.noteCam = cam;
        if (this.strumCam == null) this.strumCam = cam;
        if (this.susCam == null) this.susCam = cam;
        return super.set_camera(cam);
    }

    override function set_cameras(cams:Array<FlxCamera>):Array<FlxCamera>
    {
        if (this.noteCams == null) this.noteCams = cams;
        if (this.strumCams == null) this.strumCams = cams;
        if (this.susCams == null) this.susCams = cams;
        return super.set_cameras(cams);
    }

    override function update(elapsed:Float)
    {
        try {
            this.eventManager.update(elapsed);
            this.tweenManager.update(elapsed); //should be automatically paused when you pause in game
            this.timerManager.update(elapsed);
        } catch(e) {
            trace(e);
        }
        super.update(elapsed);
    }

    public var noteCam:FlxCamera = null;
    public var strumCam:FlxCamera = null;
    public var susCam:FlxCamera = null;

    public var noteCams:Array<FlxCamera> = null;
    public var strumCams:Array<FlxCamera> = null;
    public var susCams:Array<FlxCamera> = null;

    override public function draw()
    {
        if (this.alpha == 0 || !this.visible)
            return;

        if (this.strumCam != null) this.strumGroup.camera = this.strumCam;
        if (this.strumCams != null && this.strumCams.length > 0) this.strumGroup.cameras = this.strumCams;
        if (this.noteCam != null) this.notes.camera = this.noteCam;
        if (this.noteCams != null && this.noteCams.length > 0) this.notes.cameras = this.noteCams;

        try {
            this.drawItems(this.getNotePositions(), [this.noteCam, this.strumCam, this.susCam], [this.noteCams, this.strumCams, this.susCams]);
        } catch(e) {
            trace(e);
        }
        //draw notes to screen
    }

    private function addDataToStrum(strumData:NotePositionData, strum:StrumNoteType)
    {
        strum.x = strumData.x;
        strum.y = strumData.y;
        strum.z = strumData.z;
        strum.angle = strumData.angle;
        strum.alpha = strumData.alpha;
        strum.scale.x = strumData.scaleX;
        strum.scale.y = strumData.scaleY;
        strum.skew.x = strumData.skewX;
        strum.skew.y = strumData.skewY;
        strum.strumPositionData = strumData;
    }
    private function getDataForStrum(i:Int, pf:Int):NotePositionData
    {
        var strumX:Float = NoteMovement.defaultStrumX[i];
        var strumY:Float = NoteMovement.defaultStrumY[i];
        var strumZ:Float = 0;
        var strumScaleX:Float = NoteMovement.defaultScale[i];
        var strumScaleY:Float = NoteMovement.defaultScale[i];
        var strumSkewX:Float = NoteMovement.defaultSkewX[i];
        var strumSkewY:Float = NoteMovement.defaultSkewY[i];
        if (ModchartUtil.getIsPixelStage(instance) || ModchartUtil.getIsPixelNotes(instance))
        {
            //work on pixel stages
            strumScaleX = 1*PlayState.daPixelZoom;
            strumScaleY = 1*PlayState.daPixelZoom;
        }
        var strumData:NotePositionData = NotePositionData.get();
        strumData.setupStrum(strumX, strumY, strumZ, i, strumScaleX, strumScaleY, strumSkewX, strumSkewY, pf);
        this.playfields[pf].applyOffsets(strumData);
        this.modifierTable.applyStrumMods(strumData, i, pf);
        return strumData;
    }
    private function addDataToNote(noteData:NotePositionData, daNote:Note)
    {
        daNote.x = noteData.x;
        daNote.y = noteData.y;
        daNote.z = noteData.z;
        daNote.angle = noteData.angle;
        daNote.alpha = noteData.alpha;
        daNote.scale.x = noteData.scaleX;
        daNote.scale.y = noteData.scaleY;
        daNote.skew.x = noteData.skewX;
        daNote.skew.y = noteData.skewY;
        daNote.notePositionData = noteData;
        daNote.noteScrollSpeed = this.getCorrectScrollSpeed();
    }
    private function createDataFromNote(noteIndex:Int, playfieldIndex:Int, curPos:Float, noteDist:Float, incomingAngle:Array<Float>):NotePositionData
    {
        var noteX:Float = this.notes.members[noteIndex].x;
        var noteY:Float = this.notes.members[noteIndex].y;
        var noteZ:Float = this.notes.members[noteIndex].z;
        var lane:Int = this.getLane(noteIndex);
        var noteScaleX:Float = NoteMovement.defaultScale[lane];
        var noteScaleY:Float = NoteMovement.defaultScale[lane];
        var noteSkewX:Float = this.notes.members[noteIndex].skew.x;
        var noteSkewY:Float = this.notes.members[noteIndex].skew.y;

        var noteAlpha:Float = this.notes.members[noteIndex].multAlpha;
        if (ModchartUtil.getIsPixelStage(instance) || ModchartUtil.getIsPixelNotes(instance))
        {
            //work on pixel stages
            noteScaleX = 1*PlayState.daPixelZoom;
            noteScaleY = 1*PlayState.daPixelZoom;
        }

        var noteData:NotePositionData = NotePositionData.get();
        noteData.setupNote(noteX, noteY, noteZ, lane, noteScaleX, noteScaleY, noteSkewX, noteSkewY, playfieldIndex, noteAlpha,
            curPos, noteDist, incomingAngle[0], incomingAngle[1], this.notes.members[noteIndex].strumTime, noteIndex);
        this.playfields[playfieldIndex].applyOffsets(noteData);
        return noteData;
    }

    private function getNoteCurPos(noteIndex:Int, strumTimeOffset:Float = 0):Float
    {
        if (this.notes.members[noteIndex].isSustainNote && ModchartUtil.getDownscroll(instance))
            strumTimeOffset -= Std.int(Conductor.instance.stepCrochet/this.getCorrectScrollSpeed()); //psych does this to fix its sustains but that breaks the visuals so basically reverse it back to normal
        var distance:Float = (Conductor.instance.songPosition - this.notes.members[noteIndex].strumTime) + strumTimeOffset;
        return distance*this.getCorrectScrollSpeed();
    }
    private function getLane(noteIndex:Int):Int
    {
        //Forgot SCE changes with opponentMode and forgot to add here lmao -glow
        //Taken the && !ClientPrefs.data.middleScroll Let's see what happens now.
        if (CoolUtil.opponentModeActive)
            return (this.notes.members[noteIndex].mustPress ? notes.members[noteIndex].noteData : this.notes.members[noteIndex].noteData+NoteMovement.keyCount);
        else return (this.notes.members[noteIndex].mustPress ? notes.members[noteIndex].noteData+NoteMovement.keyCount : this.notes.members[noteIndex].noteData);
    }
    private function getNoteDist(noteIndex:Int):Float
    {
        var noteDist:Float = -0.45;
        if (ModchartUtil.getDownscroll(instance))
            noteDist *= -1;
        return noteDist;
    }

    private function getNotePositions():Array<NotePositionData>
    {
        var notePositions:Array<NotePositionData> = [];
        for (pf in 0...this.playfields.length)
        {
            for (i in 0...this.strumGroup.members.length)
            {
                var strumData = this.getDataForStrum(i, pf);
                notePositions.push(strumData);
            }

            for (i in 0...this.notes.members.length)
            {
                var lane = this.getLane(i);

                var noteDist = this.getNoteDist(i);
                noteDist = this.modifierTable.applyNoteDistMods(noteDist, lane, pf);

                var sustainTimeThingy:Float = 0;

                //just causes too many issues lol, might fix it at some point
                /*if (notes.members[i].animation.curAnim.name.endsWith('end') && ClientPrefs.downScroll)
                {
                    if (noteDist > 0)
                        sustainTimeThingy = (NoteMovement.getFakeCrochet()/4)/2; //fix stretched sustain ends (downscroll)
                    //else
                        //sustainTimeThingy = (-NoteMovement.getFakeCrochet()/4)/songSpeed;
                }*/

                var curPos = this.getNoteCurPos(i, sustainTimeThingy);
                curPos = this.modifierTable.applyCurPosMods(lane, curPos, pf);

                if ((this.notes.members[i].wasGoodHit || (this.notes.members[i].prevNote.wasGoodHit)) && curPos >= 0 && this.notes.members[i].isSustainNote)
                    curPos = 0; //sustain clip

                var incomingAngle:Array<Float> = this.modifierTable.applyIncomingAngleMods(lane, curPos, pf);
                if (noteDist < 0)
                    incomingAngle[0] += 180; //make it match for both scrolls

                //get the general note path
                NoteMovement.setNotePath(notes.members[i], lane, this.getCorrectScrollSpeed(), curPos, noteDist, incomingAngle[0], incomingAngle[1]);

                //save the position data
                var noteData = this.createDataFromNote(i, pf, curPos, noteDist, incomingAngle);

                //add offsets to data with modifiers
                this.modifierTable.applyNoteMods(noteData, lane, curPos, pf);

                //add position data to list
                notePositions.push(noteData);
            }
        }
        //sort by z while drawing
        notePositions.sort(function(a, b):Int return FlxSort.byValues(FlxSort.ASCENDING, a.z, b.z));
        return notePositions;
    }

    private function drawStrum(noteData:NotePositionData, cameraToDraw:FlxCamera, camerasToDraw:Array<FlxCamera>)
    {
        if (noteData.alpha <= 0)
            return;
        var changeX:Bool = ((noteData.z > 0 || noteData.z < 0) && noteData.z != 0);
        var strumNote:StrumNoteType = this.strumGroup.members[noteData.index];
        var thisNotePos:Vector3D = changeX ?
            ModchartUtil.calculatePerspective(new Vector3D(noteData.x+(strumNote.width/2), noteData.y+(strumNote.height/2), noteData.z*0.001),
            ModchartUtil.defaultFOV*(Math.PI/180), -(strumNote.width/2), -(strumNote.height/2))
            : new Vector3D(noteData.x, noteData.y, 0);

        noteData.x = thisNotePos.x;
        noteData.y = thisNotePos.y;
        if (changeX) {
            noteData.scaleX *= (1/-thisNotePos.z);
            noteData.scaleY *= (1/-thisNotePos.z);
        }
        // noteData.skewX = skewX + noteData.skewX;
        // noteData.skewY = skewY + noteData.skewY;

        this.addDataToStrum(noteData, this.strumGroup.members[noteData.index]); //set position and stuff before drawing
        if (cameraToDraw != null) this.strumGroup.members[noteData.index].camera = cameraToDraw;
        if (camerasToDraw != null && camerasToDraw.length > 0) this.strumGroup.members[noteData.index].cameras = camerasToDraw;
        //draw strums
        this.strumGroup.members[noteData.index].draw();
    }
    private function drawNote(noteData:NotePositionData, cameraToDraw:FlxCamera, camerasToDraw:Array<FlxCamera>)
    {
        if (noteData.alpha <= 0)
            return;
        var changeX:Bool = ((noteData.z > 0 || noteData.z < 0) && noteData.z != 0);
        var daNote:Note = this.notes.members[noteData.index];
        var thisNotePos:Vector3D = changeX ?
            ModchartUtil.calculatePerspective(new Vector3D(noteData.x+(daNote.width/2)+ModchartUtil.getNoteOffsetX(daNote, instance), noteData.y+(daNote.height/2), noteData.z*0.001),
            ModchartUtil.defaultFOV*(Math.PI/180), -(daNote.width/2), -(daNote.height/2))
            : new Vector3D(noteData.x, noteData.y, 0);

        noteData.x = thisNotePos.x;
        noteData.y = thisNotePos.y;
        if (changeX) {
            noteData.scaleX *= (1/-thisNotePos.z);
            noteData.scaleY *= (1/-thisNotePos.z);
        }
        // noteData.skewX = skewX + noteData.skewX;
        // noteData.skewY = skewY + noteData.skewY;
        //set note position using the position data
        this.addDataToNote(noteData, this.notes.members[noteData.index]);
        if (cameraToDraw != null) this.notes.members[noteData.index].camera = cameraToDraw;
        if (camerasToDraw != null && camerasToDraw.length > 0) this.notes.members[noteData.index].cameras = camerasToDraw;
        //draw it
        this.notes.members[noteData.index].draw();
    }
    private function drawSustainNote(noteData:NotePositionData, cameraToDraw:FlxCamera, camerasToDraw:Array<FlxCamera>)
    {
        if (noteData.alpha <= 0)
            return;
        var daNote:Note = this.notes.members[noteData.index];
        if (daNote.mesh == null)
            daNote.mesh = new SustainStrip(daNote);

        daNote.mesh.scrollFactor.x = daNote.scrollFactor.x;
        daNote.mesh.scrollFactor.y = daNote.scrollFactor.y;
        daNote.alpha = noteData.alpha;
        daNote.mesh.alpha = daNote.alpha;
        daNote.noteScrollSpeed = this.getCorrectScrollSpeed();
        daNote.notePositionData = noteData;

        var songSpeed = this.getCorrectScrollSpeed();
        var lane = noteData.lane;

        //makes the sustain match the center of the parent note when at weird angles
        var yOffsetThingy:Float = (NoteMovement.arrowSizes[lane]/2);

        var thisNotePos:Vector3D = ModchartUtil.calculatePerspective(new Vector3D(noteData.x+(daNote.width/2)+ModchartUtil.getNoteOffsetX(daNote, instance), noteData.y+(NoteMovement.arrowSizes[noteData.lane]/2), noteData.z*0.001),
        ModchartUtil.defaultFOV*(Math.PI/180), -(daNote.width/2), yOffsetThingy-(NoteMovement.arrowSizes[noteData.lane]/2));

        var timeToNextSustain = ModchartUtil.getFakeCrochet()/4;
        if (noteData.noteDist < 0)
            timeToNextSustain *= -1; //weird shit that fixes upscroll lol
            // timeToNextSustain = -ModchartUtil.getFakeCrochet()/4; //weird shit that fixes upscroll lol

        var nextHalfNotePos:NotePositionData = ModchartUtil.getDownscroll(instance) ? this.getSustainPoint(noteData, timeToNextSustain*0.458) : this.getSustainPoint(noteData, timeToNextSustain*0.548);
        var nextNotePos:NotePositionData = ModchartUtil.getDownscroll(instance) ? this.getSustainPoint(noteData, timeToNextSustain+2.2) : this.getSustainPoint(noteData, timeToNextSustain-2.2);

        var flipGraphic:Bool = false;

        // mod/bound to 360, add 360 for negative angles, mod again just in case
        var fixedAngY:Float = ((noteData.incomingAngleY%360)+360)%360;

        var reverseClip:Bool = (fixedAngY > 90 && fixedAngY < 270);

        if (noteData.noteDist > 0) //downscroll
        {
            if (!ModchartUtil.getDownscroll(instance)) //fix reverse
                flipGraphic = true;
        }
        else
        {
            if (ModchartUtil.getDownscroll(instance))
                flipGraphic = true;
        }
        //render that shit
        daNote.mesh.constructVertices(noteData, thisNotePos, nextHalfNotePos, nextNotePos, flipGraphic, reverseClip);

        if (cameraToDraw != null) daNote.mesh.camera = cameraToDraw;
        if (camerasToDraw != null && camerasToDraw.length > 0) daNote.mesh.cameras = camerasToDraw;
        daNote.mesh.draw();
    }

    private function drawItems(notePositions:Array<NotePositionData>, cameraDrawn:Array<FlxCamera>, camerasDrawn:Array<Array<FlxCamera>>)
    {
        for (noteData in notePositions)
        {
            if (!noteData.isStrum && !notes.members[noteData.index].isSustainNote) //draw regular note
                drawNote(noteData, cameraDrawn[0], camerasDrawn[0]);
            else if (!noteData.isStrum && notes.members[noteData.index].isSustainNote){ //draw sustain
                drawSustainNote(noteData, cameraDrawn[1], camerasDrawn[1]);
            }
            else if (noteData.isStrum) //draw strum
                drawStrum(noteData, cameraDrawn[2], camerasDrawn[2]);
        }
    }

    function getSustainPoint(noteData:NotePositionData, timeOffset:Float):NotePositionData
    {
        var daNote:Note = this.notes.members[noteData.index];
        var lane:Int = noteData.lane;
        var pf:Int = noteData.playfieldIndex;
        daNote.notePositionData = noteData;

        var noteDist:Float = getNoteDist(noteData.index);
        var curPos:Float = getNoteCurPos(noteData.index, timeOffset);

        curPos = modifierTable.applyCurPosMods(lane, curPos, pf);

        if ((daNote.wasGoodHit || (daNote.prevNote.wasGoodHit)) && curPos >= 0)
            curPos = 0;
        noteDist = modifierTable.applyNoteDistMods(noteDist, lane, pf);
        var incomingAngle:Array<Float> = modifierTable.applyIncomingAngleMods(lane, curPos, pf);
        if (noteDist < 0)
            incomingAngle[0] += 180; //make it match for both scrolls
        //get the general note path for the next note
        NoteMovement.setNotePath(daNote, lane, this.getCorrectScrollSpeed(), curPos, noteDist, incomingAngle[0], incomingAngle[1]);
        //save the position data
        var noteData:NotePositionData = createDataFromNote(noteData.index, pf, curPos, noteDist, incomingAngle);
        //add offsets to data with modifiers
        modifierTable.applyNoteMods(noteData, lane, curPos, pf);
        var yOffsetThingy:Float = (NoteMovement.arrowSizes[lane]/2);
        var finalNotePos:Vector3D = ModchartUtil.calculatePerspective(new Vector3D(noteData.x+(daNote.width/2)+ModchartUtil.getNoteOffsetX(daNote, instance), noteData.y+(NoteMovement.arrowSizes[noteData.lane]/2), noteData.z*0.001),
        ModchartUtil.defaultFOV*(Math.PI/180), -(daNote.width/2), yOffsetThingy-(NoteMovement.arrowSizes[noteData.lane]/2));

        noteData.x = finalNotePos.x;
        noteData.y = finalNotePos.y;
        noteData.z = finalNotePos.z;

        return noteData;
    }

    public var setRendererSpeed:Null<Float> = null;

    public function getCorrectScrollSpeed():Float
    {
        if (inEditor)
            return setRendererSpeed != null ? setRendererSpeed : PlayState.currentChart?.scrollSpeed ?? 1.0; //just use this while in editor so the instance shit works
        else
            return setRendererSpeed != null ? setRendererSpeed : ModchartUtil.getScrollSpeed(playStateInstance);
        return 1.0;
    }

    public function createTween(Object:Dynamic, Values:Dynamic, Duration:Float, ?Options:TweenOptions):FlxTween
    {
        var tween:FlxTween = tweenManager.tween(Object, Values, Duration, Options);
        tween.manager = tweenManager;
        return tween;
    }

    public function createTweenNum(FromValue:Float, ToValue:Float, Duration:Float = 1, ?Options:TweenOptions, ?TweenFunction:Float->Void):FlxTween
    {
        var tween:FlxTween = tweenManager.num(FromValue, ToValue, Duration, Options, TweenFunction);
        tween.manager = tweenManager;
        return tween;
    }

    public function createBezierPathTween(Object:Dynamic, Values:Dynamic, Duration:Float, ?Options:TweenOptions):FlxTween
        {
            var tween:FlxTween = tweenManager.bezierPathTween(Object, Values, Duration, Options);
            tween.manager = tweenManager;
            return tween;
        }

    public function createBezierPathNumTween(Points:Array<Float>, Duration:Float, ?Options:TweenOptions, ?TweenFunction:Float->Void):FlxTween
        {
            var tween:FlxTween = tweenManager.bezierPathNumTween(Points, Duration, Options,TweenFunction);
            tween.manager = tweenManager;
            return tween;
        }

    override public function destroy()
    {
        if (modchart != null)
        {
            #if hscript
            for (customMod in modchart.customModifiers)
            {
                customMod.destroy(); //make sure the interps are dead
            }
            #end
        }
        super.destroy();
    }

}
