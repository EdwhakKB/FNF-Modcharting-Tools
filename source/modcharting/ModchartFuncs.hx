package modcharting;

import haxe.Json;
import openfl.net.FileReference;
import flixel.FlxG;
#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

#if LUA_ALLOWED
import psychlua.FunkinLua;
import psychlua.HScript as FunkinHScript;
#end

import modcharting.Modifier;
import modcharting.PlayfieldRenderer;
import modcharting.NoteMovement;
import modcharting.ModchartUtil;

import openfl.events.Event;
import openfl.events.IOErrorEvent;

using StringTools;

//for lua and hscript
class ModchartFuncs
{
    public static function loadLuaFunctions(funk:FunkinLua)
    {
        #if LUA_ALLOWED
        funk.set('startMod', function(name:String, modClass:String, type:String = '', pf:Int = -1){
            startMod(name,modClass,type,pf);

            PlayState.instance.playfieldRenderer.modifierTable.reconstructTable(); //needs to be reconstructed for lua modcharts
        });
        funk.set('setMod', function(name:String, value:Float){
            setMod(name, value);
        });
        funk.set('setSubMod', function(name:String, subValName:String, value:Float){
            setSubMod(name, subValName,value);
        });
        funk.set('setModTargetLane', function(name:String, value:Int){
            setModTargetLane(name, value);
        });
        funk.set('setModPlayfield', function(name:String, value:Int){
            setModPlayfield(name,value);
        });
        funk.set('addPlayfield', function(?x:Float = 0, ?y:Float = 0, ?z:Float = 0){
            addPlayfield(x,y,z);
        });
        funk.set('removePlayfield', function(idx:Int){
            removePlayfield(idx);
        });
        funk.set('tweenModifier', function(modifier:String, val:Float, time:Float, ease:String){
            tweenModifier(modifier,val,time,ease);
        });
        funk.set('tweenModifierSubValue', function(modifier:String, subValue:String, val:Float, time:Float, ease:String){
            tweenModifierSubValue(modifier,subValue,val,time,ease);
        });
        funk.set('setModEaseFunc', function(name:String, ease:String){
            setModEaseFunc(name,ease);
        });
        funk.set('set', function(beat:Float, argsAsString:String){
            set(beat, argsAsString);
        });
        funk.set('ease', function(beat:Float, time:Float, easeStr:String, argsAsString:String){
            ease(beat, time, easeStr, argsAsString);                
        });
            
        loadHaxeFunctions(funk);
        #end
    }

    
    public static function loadHaxeFunctions(funkin:FunkinLua)
        {
            #if HSCRIPT_ALLOWED
            FunkinHScript.initHaxeModule(funkin);
    
            if (funkin.hscript != null)
            {
                #if (SScript >= "6.1.80")
                    funkin.hscript.setClass(Math);
                    funkin.hscript.setClass(PlayfieldRenderer);
                    funkin.hscript.setClass(ModchartUtil);
                    funkin.hscript.setClass(Modifier);
                    funkin.hscript.setClass(NoteMovement);
                    funkin.hscript.setClass(NotePositionData);
                    funkin.hscript.setClass(ModchartFile);
                #else
                    funkin.hscript.set('Math', Math);
                    funkin.hscript.set('PlayfieldRenderer', PlayfieldRenderer);
                    funkin.hscript.set('ModchartUtil', ModchartUtil);
                    funkin.hscript.set('Modifier', Modifier);
                    funkin.hscript.set('NoteMovement', NoteMovement);
                    funkin.hscript.set('NotePositionData', NotePositionData);
                    funkin.hscript.set('ModchartFile', ModchartFile);
                #end
            }
            #end
        }
    public static function loadHScriptFunctions(parent:Dynamic)
    {
        #if HSCRIPT_ALLOWED
        parent.set('startMod', function(name:String, modClass:String, type:String = '', pf:Int = -1){
            startMod(name, modClass, type, pf);

            if (PlayState.instance == FlxG.state && PlayState.instance.playfieldRenderer != null)
            {
                PlayState.instance.playfieldRenderer.modifierTable.reconstructTable(); //needs to be reconstructed for lua modcharts
            }
        });
        parent.set('setMod', function(name:String, value:Float){
            setMod(name, value);
        });
        parent.set('setSubMod', function(name:String, subValName:String, value:Float){
            setSubMod(name, subValName,value);
        });
        parent.set('setModTargetLane', function(name:String, value:Int){
            setModTargetLane(name, value);
        });
        parent.set('setModPlayfield', function(name:String, value:Int){
            setModPlayfield(name,value);
        });
        parent.set('addPlayfield', function(?x:Float = 0, ?y:Float = 0, ?z:Float = 0){
            addPlayfield(x,y,z);
        });
        parent.set('removePlayfield', function(idx:Int){
            removePlayfield(idx);
        });
        parent.set('tweenModifier', function(modifier:String, val:Float, time:Float, ease:String){
            tweenModifier(modifier,val,time,ease);
        });
        parent.set('tweenModifierSubValue', function(modifier:String, subValue:String, val:Float, time:Float, ease:String){
            tweenModifierSubValue(modifier,subValue,val,time,ease);
        });
        parent.set('setModEaseFunc', function(name:String, ease:String){
            setModEaseFunc(name,ease);
        });
        parent.set('setModValue', function(beat:Float, argsAsString:String){
            set(beat, argsAsString);
        });
        parent.set('easeModValue', function(beat:Float, time:Float, easeStr:String, argsAsString:String){
            ease(beat, time, easeStr, argsAsString);
        });
        #end
    }

    public static function startMod(name:String, modClass:String, type:String = '', pf:Int = -1, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
        {
            instance = PlayState.instance;
            if (instance.playfieldRenderer.modchart != null)
                if (instance.playfieldRenderer.modchart.scriptListen)
                {
                    instance.playfieldRenderer.modchart.data.modifiers.push([name, modClass, type, pf]);
                    trace(name,modClass,type,pf);
                }
        }

        if (instance.playfieldRenderer.modchart != null)
            if (instance.playfieldRenderer.modchart.customModifiers.exists(modClass))
            {
                var modifier = new Modifier(name, getModTypeFromString(type), pf);
                if (instance.playfieldRenderer.modchart.customModifiers.get(modClass).interp != null)
                    instance.playfieldRenderer.modchart.customModifiers.get(modClass).interp.variables.set('instance', instance);
                instance.playfieldRenderer.modchart.customModifiers.get(modClass).initMod(modifier); //need to do it this way instead because using current value in the modifier script didnt work
                //var modifier = instance.playfieldRenderer.modchart.customModifiers.get(modClass).copy();
                //modifier.tag = name; //set correct stuff because its copying shit
                //modifier.playfield = pf;
                //modifier.type = getModTypeFromString(type);
                instance.playfieldRenderer.modifierTable.add(modifier);
                return;
            }

        var mod = Type.resolveClass('modcharting.'+modClass);
        if (mod == null) {mod = Type.resolveClass('modcharting.'+modClass+"Modifier");} //dont need to add "Modifier" to the end of every mod

        if (mod != null)
        {
            var modType = getModTypeFromString(type);
            var modifier = Type.createInstance(mod, [name, modType, pf]);
            instance.playfieldRenderer.modifierTable.add(modifier);
        }
    }
    public static function getModTypeFromString(type:String)
    {
        var modType = ModifierType.ALL;
        switch (type.toLowerCase())
        {
            case 'player':
                modType = ModifierType.PLAYERONLY;
            case 'opponent':
                modType = ModifierType.OPPONENTONLY;
            case 'lane' | 'lanespecific':
                modType = ModifierType.LANESPECIFIC;
        }
        return modType;
    }

    public static function setMod(name:String, value:Float, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
            instance = PlayState.instance;
        if (instance.playfieldRenderer.modchart != null)
            if (instance.playfieldRenderer.modchart.scriptListen)
            {
                instance.playfieldRenderer.modchart.data.events.push(["set", [0, value+","+name]]);
            }
        if (instance.playfieldRenderer.modifierTable.modifiers.exists(name))
            instance.playfieldRenderer.modifierTable.modifiers.get(name).currentValue = value;
    }
    public static function setSubMod(name:String, subValName:String, value:Float, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
            instance = PlayState.instance;
        if (instance.playfieldRenderer.modchart != null)
            if (instance.playfieldRenderer.modchart.scriptListen)
            {
                instance.playfieldRenderer.modchart.data.events.push(["set", [0, value+","+name+":"+subValName]]);
            }
        if (instance.playfieldRenderer.modifiers.exists(name))
            if (instance.playfieldRenderer.modifiers.get(name).subValues.exists(subValName))
                instance.playfieldRenderer.modifiers.get(name).subValues.get(subValName).value = value;
            else
                instance.playfieldRenderer.modifiers.get(name).subValues.set(subValName,new Modifier.ModifierSubValue(value));
    }
    public static function setModTargetLane(name:String, value:Int, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
            instance = PlayState.instance;
        if (instance.playfieldRenderer.modifierTable.modifiers.exists(name))
            instance.playfieldRenderer.modifierTable.modifiers.get(name).targetLane = value;
    }
    public static function setModPlayfield(name:String, value:Int, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
            instance = PlayState.instance;
        if (instance.playfieldRenderer.modifierTable.modifiers.exists(name))
            instance.playfieldRenderer.modifierTable.modifiers.get(name).playfield = value;
    }
    public static function addPlayfield(?x:Float = 0, ?y:Float = 0, ?z:Float = 0, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
            instance = PlayState.instance;
        instance.playfieldRenderer.addNewPlayfield(x,y,z);
    }
    public static function removePlayfield(idx:Int, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
            instance = PlayState.instance;
        instance.playfieldRenderer.playfields.remove(instance.playfieldRenderer.playfields[idx]);
    }

    public static function tweenModifier(modifier:String, val:Float, time:Float, ease:String, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
            instance = PlayState.instance;
        instance.playfieldRenderer.modifierTable.tweenModifier(modifier,val,time,ease, Modifier.beat);
    }

    public static function tweenModifierSubValue(modifier:String, subValue:String, val:Float, time:Float, ease:String, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
            instance = PlayState.instance;
        instance.playfieldRenderer.modifierTable.tweenModifierSubValue(modifier,subValue,val,time,ease, Modifier.beat);
    }

    public static function setModEaseFunc(name:String, ease:String, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
            instance = PlayState.instance;
        if (instance.playfieldRenderer.modifierTable.modifiers.exists(name))
        {
            var mod = instance.playfieldRenderer.modifierTable.modifiers.get(name);
            if (Std.isOfType(mod, EaseCurveModifier))
            {
                var temp:Dynamic = mod;
                var castedMod:EaseCurveModifier = temp;
                castedMod.setEase(ease);
            }
        }
    }
    public static function set(beat:Float, argsAsString:String, ?instance:ModchartMusicBeatState = null)
    {
        if (instance == null)
        {
            instance = PlayState.instance;
            if (instance.playfieldRenderer.modchart != null)
                if (instance.playfieldRenderer.modchart.scriptListen)
                {
                    instance.playfieldRenderer.modchart.data.events.push(["set", [beat, argsAsString]]);
                }
        }
        var args = argsAsString.trim().replace(' ', '').split(',');

        instance.playfieldRenderer.eventManager.addEvent(beat, function(arguments:Array<String>) {
            for (i in 0...Math.floor(arguments.length/2))
            {
                var name:String = Std.string(arguments[1 + (i*2)]);
                var value:Float = Std.parseFloat(arguments[0 + (i*2)]);
                if(Math.isNaN(value))
                    value = 0;
                if (instance.playfieldRenderer.modifierTable.modifiers.exists(name))
                {
                    instance.playfieldRenderer.modifierTable.modifiers.get(name).currentValue = value;
                }
                else 
                {
                    var subModCheck = name.split(':');
                    if (subModCheck.length > 1)
                    {
                        var modName = subModCheck[0];
                        var subModName = subModCheck[1];
                        if (instance.playfieldRenderer.modifierTable.modifiers.exists(modName))
                            instance.playfieldRenderer.modifierTable.modifiers.get(modName).subValues.get(subModName).value = value;
                    }
                }
                    
            }
        }, args);
    }
    public static function ease(beat:Float, time:Float, ease:String, argsAsString:String, ?instance:ModchartMusicBeatState = null) : Void
    {
        if (instance == null)
        {
            instance = PlayState.instance;
            if (instance.playfieldRenderer.modchart != null)
                if (instance.playfieldRenderer.modchart.scriptListen)
                {
                    instance.playfieldRenderer.modchart.data.events.push(["ease", [beat, time, ease, argsAsString]]);
                }
        }
            
        if(Math.isNaN(time))
            time = 1;

        var args = argsAsString.trim().replace(' ', '').split(',');

        var func = function(arguments:Array<String>) {
            
            for (i in 0...Math.floor(arguments.length/2))
            {
                var name:String = Std.string(arguments[1 + (i*2)]);
                var value:Float = Std.parseFloat(arguments[0 + (i*2)]);
                if(Math.isNaN(value))
                    value = 0;
                var subModCheck = name.split(':');
                if (subModCheck.length > 1)
                {
                    var modName = subModCheck[0];
                    var subModName = subModCheck[1];
                    //trace(subModCheck);
                    instance.playfieldRenderer.modifierTable.tweenModifierSubValue(modName,subModName,value,time*Conductor.instance.beatLengthMs*0.001,ease, beat);
                }
                else
                    instance.playfieldRenderer.modifierTable.tweenModifier(name,value,time*Conductor.instance.beatLengthMs*0.001,ease, beat);
                
            }
        };
        instance.playfieldRenderer.eventManager.addEvent(beat, func, args);
    }
    
}
