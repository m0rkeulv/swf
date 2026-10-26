package swf.exporters.animate;

import haxe.Json;

/**
	Writes the `data.json` and the manifest of an `animate` bundle with every object's fields in alphabetical order.
	`Json.stringify` writes fields in the order the target stores them, which differs between Neko and
	HashLink; with the order fixed, the tool writes the same bytes on both. Values are printed by
	`Json.stringify`, so numbers and strings look exactly as before.
**/
class AnimateJsonWriter
{
	public static function stringify(value:Dynamic):String
	{
		var buffer = new StringBuf();
		write(buffer, value);
		return buffer.toString();
	}

	private static function write(buffer:StringBuf, value:Dynamic):Void
	{
		if (value == null || Std.isOfType(value, String) || Std.isOfType(value, Bool) || Std.isOfType(value, Float))
		{
			buffer.add(Json.stringify(value));
		}
		else if (Std.isOfType(value, Array))
		{
			var list:Array<Dynamic> = value;
			buffer.addChar("[".code);
			for (i in 0...list.length)
			{
				if (i > 0) buffer.addChar(",".code);
				write(buffer, list[i]);
			}
			buffer.addChar("]".code);
		}
		else
		{
			// a class instance (the manifest) by its data fields, as Json.stringify prints it
			var fields = switch (Type.typeof(value))
			{
				case TClass(c): [for (field in Type.getInstanceFields(c)) if (!Reflect.isFunction(Reflect.field(value, field))) field];
				default: Reflect.fields(value);
			}
			fields.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
			buffer.addChar("{".code);
			for (i in 0...fields.length)
			{
				if (i > 0) buffer.addChar(",".code);
				buffer.add(Json.stringify(fields[i]));
				buffer.addChar(":".code);
				write(buffer, Reflect.field(value, fields[i]));
			}
			buffer.addChar("}".code);
		}
	}
}
