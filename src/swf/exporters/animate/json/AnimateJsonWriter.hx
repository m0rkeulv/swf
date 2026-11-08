package swf.exporters.animate.json;

import haxe.Json;
import swf.exporters.animate.AnimateSymbolType;
import swf.exporters.animate.document.*;

/**
	Writes an `AnimateDocument` as the text of `data.json`. Each object lists its fields in alphabetical
	order and leaves out the ones that are null, so the text does not depend on the target the tool runs
	on. Numbers print as `Json.stringify` prints them, through `Std.string`, and strings through
	`Json.stringify` itself, so values look as they did.
**/
class AnimateJsonWriter
{
	private var buffer:StringBuf;
	/** Whether the next field is the first of its object, which no comma precedes. **/
	private var first:Bool;

	public static function stringify(document:AnimateDocument):String
	{
		var writer = new AnimateJsonWriter();
		writer.begin();
		writer.float("frameRate", document.frameRate);
		writer.int("root", 0);
		writer.key("symbols");
		writer.list(document.symbolList(), writer.symbol);
		writer.string("uuid", document.uuid);
		writer.float("version", 0.1);
		writer.end();
		return writer.buffer.toString();
	}

	/**
		A value of no fixed shape (a frame object's `metaData`, the bundle's manifest), with the fields of
		every object in alphabetical order, where `Json.stringify` would print them in an order that
		differs between targets.
	**/
	public static function value(v:Dynamic):String
	{
		var writer = new AnimateJsonWriter();
		writer.dynamicValue(v);
		return writer.buffer.toString();
	}

	private function new()
	{
		buffer = new StringBuf();
	}

	// ------------------------------------------------------------------------------------ symbols

	private function symbol(symbol:AnimateDocumentSymbol):Void
	{
		begin();
		switch (symbol.type)
		{
			case BITMAP: bitmap(cast symbol);
			case BUTTON: button(cast symbol);
			case DYNAMIC_TEXT: dynamicText(cast symbol);
			case FONT: font(cast symbol);
			case SHAPE: shape(cast symbol);
			case SPRITE: sprite(cast symbol);
			case STATIC_TEXT: staticText(cast symbol);
			default: throw "AnimateJsonWriter: unknown symbol type " + symbol.type;
		}
		end();
	}

	private function bitmap(symbol:AnimateDocumentBitmap):Void
	{
		string("alpha", symbol.alpha);
		string("baseClassName", symbol.baseClassName);
		string("className", symbol.className);
		int("id", symbol.id);
		string("path", symbol.path);
		bool("smooth", symbol.smooth);
		int("type", symbol.type);
	}

	private function button(symbol:AnimateDocumentButton):Void
	{
		string("baseClassName", symbol.baseClassName);
		string("className", symbol.className);
		state("downState", symbol.downState);
		state("hitState", symbol.hitState);
		int("id", symbol.id);
		state("overState", symbol.overState);
		int("type", symbol.type);
		state("upState", symbol.upState);
	}

	private function state(name:String, sprite:AnimateDocumentSprite):Void
	{
		if (sprite == null) return;
		key(name);
		begin();
		this.sprite(sprite);
		end();
	}

	private function dynamicText(symbol:AnimateDocumentDynamicText):Void
	{
		string("align", symbol.align);
		string("baseClassName", symbol.baseClassName);
		bool("border", symbol.border);
		string("className", symbol.className);
		int("color", symbol.color);
		int("fontHeight", symbol.fontHeight);
		int("fontID", symbol.fontID);
		string("fontName", symbol.fontName);
		bool("html", symbol.html);
		int("id", symbol.id);
		int("indent", symbol.indent);
		bool("input", symbol.input);
		int("leading", symbol.leading);
		int("leftMargin", symbol.leftMargin);
		bool("multiline", symbol.multiline);
		bool("password", symbol.password);
		numbers("rect", symbol.rect);
		int("rightMargin", symbol.rightMargin);
		bool("selectable", symbol.selectable);
		string("text", symbol.text);
		int("type", symbol.type);
		bool("wordWrap", symbol.wordWrap);
	}

	private function font(symbol:AnimateDocumentFont):Void
	{
		numbers("advances", symbol.advances);
		int("ascent", symbol.ascent);
		string("baseClassName", symbol.baseClassName);
		bool("bold", symbol.bold);
		string("className", symbol.className);
		numbers("codes", symbol.codes);
		int("descent", symbol.descent);
		tokens("glyphs", symbol.glyphs);
		int("id", symbol.id);
		bool("italic", symbol.italic);
		int("leading", symbol.leading);
		string("name", symbol.name);
		int("type", symbol.type);
	}

	private function shape(symbol:AnimateDocumentShape):Void
	{
		string("baseClassName", symbol.baseClassName);
		string("className", symbol.className);
		tokens("commands", symbol.commands);
		int("id", symbol.id);
		int("type", symbol.type);
	}

	private function sprite(symbol:AnimateDocumentSprite):Void
	{
		string("baseClassName", symbol.baseClassName);
		string("className", symbol.className);
		key("frames");
		list(symbol.frames, frame);
		int("id", symbol.id);
		numbers("scale9Grid", symbol.scale9Grid);
		int("type", symbol.type);
	}

	private function staticText(symbol:AnimateDocumentStaticText):Void
	{
		string("baseClassName", symbol.baseClassName);
		string("className", symbol.className);
		int("id", symbol.id);
		numbers("matrix", symbol.matrix);
		if (symbol.records != null)
		{
			key("records");
			list(symbol.records, record);
		}
		int("type", symbol.type);
	}

	private function frame(frame:AnimateDocumentFrame):Void
	{
		begin();
		if (frame.labels != null)
		{
			key("labels");
			dynamicValue(frame.labels);
		}
		if (frame.objects != null)
		{
			key("objects");
			list(frame.objects, frameObject);
		}
		string("scriptSource", frame.scriptSource);
		end();
	}

	private function frameObject(object:AnimateDocumentFrameObject):Void
	{
		begin();
		string("blendMode", object.blendMode);
		bool("cacheAsBitmap", object.cacheAsBitmap);
		int("clipDepth", object.clipDepth);
		numbers("colorTransform", object.colorTransform);
		int("depth", object.depth);
		tokens("filters", object.filters);
		int("id", object.id);
		numbers("matrix", object.matrix);
		if (object.metaData != null)
		{
			key("metaData");
			dynamicValue(object.metaData);
		}
		string("name", object.name);
		int("symbol", object.symbol);
		int("type", object.type);
		bool("visible", object.visible);
		end();
	}

	private function record(record:AnimateDocumentTextRecord):Void
	{
		begin();
		numbers("advances", record.advances);
		int("color", record.color);
		int("fontHeight", record.fontHeight);
		int("fontID", record.fontID);
		numbers("glyphs", record.glyphs);
		numbers("offset", record.offset);
		end();
	}

	// ------------------------------------------------------------------------------------ fields

	private inline function begin():Void
	{
		buffer.addChar("{".code);
		first = true;
	}

	private inline function end():Void
	{
		buffer.addChar("}".code);
		// whatever follows a closed object is not the first field of its own object
		first = false;
	}

	private function key(name:String):Void
	{
		if (first) first = false;
		else buffer.addChar(",".code);
		buffer.addChar('"'.code);
		buffer.add(name);
		buffer.add('":');
	}

	private function list<T>(items:Array<T>, write:T->Void):Void
	{
		buffer.addChar("[".code);
		for (i in 0...items.length)
		{
			if (i > 0) buffer.addChar(",".code);
			write(items[i]);
		}
		buffer.addChar("]".code);
	}

	private function int(name:String, v:Null<Int>):Void
	{
		if (v == null) return;
		key(name);
		buffer.add(v);
	}

	private function float(name:String, v:Null<Float>):Void
	{
		if (v == null) return;
		key(name);
		if (Math.isFinite(v)) buffer.add(v);
		else buffer.add("null");
	}

	private function bool(name:String, v:Null<Bool>):Void
	{
		if (v == null) return;
		key(name);
		buffer.add(v ? "true" : "false");
	}

	private function string(name:String, v:String):Void
	{
		if (v == null) return;
		key(name);
		buffer.add(Json.stringify(v));
	}

	/** An array of numbers, a null entry (a gap in a font's advance table) printed as null. **/
	private function numbers(name:String, v:Array<Dynamic>):Void
	{
		if (v == null) return;
		key(name);
		buffer.addChar("[".code);
		for (i in 0...v.length)
		{
			if (i > 0) buffer.addChar(",".code);
			number(v[i]);
		}
		buffer.addChar("]".code);
	}

	/** A token array (shape commands, filters, glyphs): numbers, bools, strings and nested arrays. **/
	private function tokens(name:String, v:Array<Dynamic>):Void
	{
		if (v == null) return;
		key(name);
		dynamicValue(v);
	}

	/** A number of either kind, or null; printed as `Json.stringify` prints it, straight into the buffer. **/
	private function number(v:Dynamic):Void
	{
		switch (Type.typeof(v))
		{
			case TInt: buffer.add(v);
			case TFloat: if (Math.isFinite(v)) buffer.add(v) else buffer.add("null");
			default: buffer.add("null");
		}
	}

	private function dynamicValue(v:Dynamic):Void
	{
		// one type test per value, as Json.stringify does it
		switch (Type.typeof(v))
		{
			case TNull:
				buffer.add("null");
			case TInt:
				buffer.add(v);
			case TFloat:
				// not a ternary: with v Dynamic the expression would be typed String, which HashLink
				// cannot cast a float to
				if (Math.isFinite(v)) buffer.add(v) else buffer.add("null");
			case TBool:
				buffer.add((v : Bool) ? "true" : "false");
			case TClass(String):
				buffer.add(Json.stringify(v));
			case TClass(Array):
				var items:Array<Dynamic> = v;
				buffer.addChar("[".code);
				for (i in 0...items.length)
				{
					if (i > 0) buffer.addChar(",".code);
					dynamicValue(items[i]);
				}
				buffer.addChar("]".code);
			default:
				// a class instance (the manifest) by its data fields, as Json.stringify prints it
				var fields = switch (Type.typeof(v))
				{
					case TClass(c): [for (field in Type.getInstanceFields(c)) if (!Reflect.isFunction(Reflect.field(v, field))) field];
					default: Reflect.fields(v);
				}
				fields.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
				buffer.addChar("{".code);
				for (i in 0...fields.length)
				{
					if (i > 0) buffer.addChar(",".code);
					buffer.add(Json.stringify(fields[i]));
					buffer.addChar(":".code);
					dynamicValue(Reflect.field(v, fields[i]));
				}
				buffer.addChar("}".code);
		}
	}
}
