package modcharting;

import states.PlayState;
import objects.Note;

using StringTools;

class NoteMovement
{
    public static var keyCount:Int = 4;
    public static var playerKeyCount:Int = 4;
    public static var totalKeyCount:Int = 8;
    public static var arrowScale:Float = 0.7;
    public static var arrowSize:Float = 112;
    public static var defaultStrumX:Array<Float> = [];
    public static var defaultStrumY:Array<Float> = [];
    public static var defaultSkewX:Array<Float> = [];
    public static var defaultSkewY:Array<Float> = [];
    public static var defaultScale:Array<Float> = [];
    public static var arrowSizes:Array<Float> = [];

    public static function getDefaultStrumPos(game:PlayState)
    {
        defaultStrumX = []; //reset
        defaultStrumY = []; 
        defaultSkewX = [];
        defaultSkewY = []; 
        defaultScale = [];
        arrowSizes = [];
        keyCount = game.strumLineNotes.length-game.playerStrums.length; //base game doesnt have opponent strums as group
        playerKeyCount = game.playerStrums.length;

        for (i in 0...game.strumLineNotes.members.length)
        {
            var strum = game.strumLineNotes.members[i];
            defaultSkewX.push(strum.skew.x);
            defaultSkewY.push(strum.skew.y);
            defaultStrumX.push(strum.x);
            defaultStrumY.push(strum.y);
            var s = 0.7;

            defaultScale.push(s);
            arrowSizes.push(160*s);
        }
        totalKeyCount = keyCount + playerKeyCount;
    }
    
    public static function getDefaultStrumPosEditor(game:modcharting.ModchartEditorState)
    {
        #if (!DISABLE_MODCHART_EDITOR)
        defaultStrumX = []; //reset
        defaultStrumY = []; 
        defaultSkewX = [];
        defaultSkewY = [];
        defaultScale = [];
        arrowSizes = [];
        keyCount = game.strumLineNotes.length-game.playerStrums.length; //base game doesnt have opponent strums as group
        playerKeyCount = game.playerStrums.length;

        for (i in 0...game.strumLineNotes.members.length)
        {
            var strum = game.strumLineNotes.members[i];
            defaultSkewX.push(strum.skew.x);
            defaultSkewY.push(strum.skew.y);
            defaultStrumX.push(strum.x);
            defaultStrumY.push(strum.y);
            var s = 0.7;

            defaultScale.push(s);
            arrowSizes.push(160*s);
        }
        #end
    }

    public static function setNotePath(daNote:Note, lane:Int, scrollSpeed:Float, curPos:Float, noteDist:Float, incomingAngleX:Float, incomingAngleY:Float)
    {
        daNote.x = defaultStrumX[lane];
        daNote.y = defaultStrumY[lane];
        daNote.z = 0;

        var pos = ModchartUtil.getCartesianCoords3D(incomingAngleX, incomingAngleY, curPos*noteDist);
        daNote.y += pos.y;
        daNote.x += pos.x;
        daNote.z += pos.z;

        daNote.skew.x = defaultSkewX[lane];
        daNote.skew.y = defaultSkewY[lane];
    }

    public static function getLaneDiffFromCenter(lane:Int)
    {
        var col:Float = lane%4;
        if ((col+1) > (keyCount*0.5))
        {
            col -= (keyCount*0.5)+1;
        }
        else 
        {
            col -= (keyCount*0.5);
        }
        //col = (col-col-col); //flip pos/negative
        //trace(col);
        return col;
    }
}

