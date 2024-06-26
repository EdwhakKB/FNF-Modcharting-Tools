package modcharting;

import flixel.util.FlxSort;

class ModchartEventManager
{
    public var renderer:PlayfieldRenderer;
    public function new(renderer:PlayfieldRenderer)
    {
        this.renderer = renderer;
    }
    public var events:Array<ModchartEvent> = [];
    public function update(elapsed:Float)
    {
        if (events.length > 1)
        {
            events.sort(function(a:ModchartEvent, b:ModchartEvent):Int {
                if (a.time < b.time) return -1;
                else if (a.time > b.time) return 1;
                return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time);
            });
        }
		while(events.length > 0) {
			var event:ModchartEvent = events[0];
			if(Conductor.instance.songPosition < event.time) {
				break;
			}
            //Reflect.callMethod(this, event.func, event.args);
            event.func(event.args);
			events.shift();
		}
        Modifier.beat = ((Conductor.instance.songPosition *0.001)*(Conductor.instance.bpm/60));
    }

    public function addEvent(beat:Float, func:Array<String>->Void, args:Array<String>)
    {
        var time = ModchartUtil.getTimeFromBeat(beat);
        events.push(new ModchartEvent(time, func, args));
    }

    public function clearEvents()
    {
        events = [];
    }
}