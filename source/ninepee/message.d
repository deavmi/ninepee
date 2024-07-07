module ninepee.message;

public static bool isRequest(MType type)
{
	return type % 2 == 0;
}

public static bool isReply(MType type)
{
	return !isRequest(type);
}

public enum MType : ubyte
{
	Tversion = 100,
	Rversion = 101,
	Tauth = 102,
	Rauth = 103,
	Tattach = 104,
	Rattach = 105,
	Terror = 106,
	Rerror = 107,
	Tflush = 108,
	Rflush = 109,
	Twalk = 110,
	Rwalk = 111,
	Topen = 112,
	Ropen = 113,
	Tcreate = 114,
	Rcreate = 115,
	Tread = 116,
	Rread = 117,
	Twrite = 118,
	Rwrite = 119,
	Tclunk = 120,
	Rclunk = 121,
	Tremove = 122,
	Rremove = 123,
	Tstat = 124,
	Rstat = 125,
	Twstat = 126,
	Rwstat = 127
}

import niknaks.bits;

public abstract class Message
{
	private MType type;
	private Tag tag;

	this(MType type)
	{
		this.type = type;
	}
	
	public final MType getType()
	{
		return this.type;
	}

	public final ubyte[] encode()
	{
		ubyte[] o;

		// firstly obtain the bytes AFTER tag[2]
		// Obtain the encoded message (from AFTER tag[2] onwards)
		ubyte[] sub = getPayload();
		writeln("sub bytes below:");
		version(DBG_ARR_DUMPS) { writeln(dumpArray!(sub)()); }
		
		// Calculate total length as size[4] type[1] tag[2] sub[sub.length]
		uint len = cast(uint)(4+1+2+sub.length);
		writeln(format("total 9p msg len is: %d bytes", len));

		// take length ensure it is in LE ordering, then append
		o ~= toBytes(order(len, Order.LE));

		// tack on mtype
		o ~= this.type;

		// take tag ensure it is in LE ordering, then append
		o ~= toBytes(order(this.tag, Order.LE));

		// tack on the sub-message
		o ~= sub;
		
		writeln(format("Byte output for (%s):\n%s", this, dumpArray!(o)));
		
		return [];
	}
	
	public final Tag getTag()
	{
		return this.tag;
	}

	public final void setTag(Tag tag)
	{
		// TODO: Check tag value, there is this "NO_TAG" thing too
		this.tag = tag;
	}

	// encodes the message part
	public abstract ubyte[] getPayload();

	public final size_t getPayloadSize()
	{
		return getPayload().length;
	}
}

public class VersionMessage_V2 : Message
{
	// maximum message size allowed
	private uint msize;

	// protocol version to use
	private string ver;

	private this(MType type)
	{
		super(type);
	}

	// TODO: Return a Result rather as we need to ensure the incoming string is valid
	public static VersionMessage_V2 makeRequest(uint msize, string ver)
	{
		VersionMessage_V2 mesg = new VersionMessage_V2(MType.Tversion);
		mesg.msize = msize;
		mesg.ver = ver;
		return mesg;
	}

	public static VersionMessage_V2 makeReply(uint msize, string ver)
	{
		VersionMessage_V2 mesg = new VersionMessage_V2(MType.Rversion);
		mesg.msize = msize;
		mesg.ver = ver;
		return mesg;
	}

	public override ubyte[] getPayload()
	{
		ubyte[] o;

		// ensure LE ordering and tack on to byte array
		o ~= toBytes(order(this.msize, Order.LE));

		// add version
		o ~= ver;

		return o;
	}
}

unittest
{
	Message msg = VersionMessage_V2.makeRequest(2000, "9P1000");

	ubyte[] o = msg.encode();
}

public struct VersionMessage
{
	// true if Tversion, false if Rversion
	private bool isRequest;

	// maximum message size allowed
	private uint msize;

	// protocol version to use
	private string ver;

	@disable
	this();

	this(uint msize, string ver, bool isRequest)
	{
		this.isRequest = isRequest;
		this.msize = msize;
		this.ver = ver;
	}

	public MType getType()
	{
		return isRequest ? MType.Tversion : MType.Rversion;
	}

	public ubyte[] getPayload()
	{
		ubyte[] o;

		// ensure LE ordering and tack on to byte array
		o ~= toBytes(order(this.msize, Order.LE));

		// add version
		o ~= ver;

		return o;
	}
}

unittest
{
	struct Base
	{
		int kek=69;
		int getAge()
		{
			return kek;
		}
	}

	struct J
	{
		
	}

	J j = J();
	Base* b = cast(Base*)(&j);

	writeln(b.getAge());
}

// TODO: Use niknaks.result type rather?
public bool decode(ref Message messageOut, ref string errOut)
{
	return true;
}

unittest
{
	
}

public struct D
{
	// int encode;
}

import niknaks.debugging;

// FIXME: If any debug is enabled import std.stdio
// ... have a versioning check for this
version(DEBUG_ARR_DUMPS)
{
	// import std.stdio : writeln;
}

import std.stdio : writeln;
import std.string : format;

public void doEncode(MessageType)(MessageType message)
if(isMessage!(MessageType)) // FIXME: Call isSerializable rather (TODO: Updte unittests then)
{
	writeln(show(message));
	
	// Obtain the encoded message (from AFTER tag[2] onwards)
	ubyte[] sub = message.getPayload();
	writeln("sub bytes below:");
	version(DBG_ARR_DUMPS) { writeln(dumpArray!(sub)()); }

	// Calculate total length as size[4] type[1] tag[2] sub[sub.length]
	uint len = cast(uint)(4+1+2+sub.length);
	writeln(format("total 9p msg len is: %d bytes", len));
}

public string show(MessageType)(MessageType m)
if(isSerializable!(MessageType))
{
	// TODO: show firts few bytes
	ubyte[] payload = m.getPayload();
	uint len = cast(uint)payload.length;

	import std.conv : to;
	return format
	(
		"9P Message [size: %d, type: %s, tag: %d]",
		len, // TODO: Set to size getSize()
		m.getType(),
		m.getTag()
	);
}


alias Tag = ushort;

unittest
{
	struct Ting
	{
		Tag getTag()
		{
			return 69;
		}
		
		MType getType()
		{
			return MType.Twrite;
		}
	
		ubyte[] getPayload()
		{
			return [66, 65, 65, 66];
		}
	}

	auto msg = Ting();
	doEncode(msg);

	writeln(msg);
}

import std.traits;

public bool isMessage(MessageType)()
{
	// Needs to have a member named `getPayload`
	if(!hasMember!(MessageType, "getPayload"))
	{
		return false;
	}

	// Alias for the encode symbol
	alias member = __traits(getMember, MessageType, "getPayload");

	// Ensure it is a function, has zero arity and has a `ubyte[]` return type
	pragma(msg, isFunction!(member));
	pragma(msg, arity!(member));
	pragma(msg, ReturnType!(member));
	if(isFunction!(member) && arity!(member) == 0 && __traits(isSame, ubyte[], ReturnType!(member)))
	{
		return true;
	}
	else
	{
		return false;
	}
}

public bool isSerializable(MessageType)()
{
	return hasTypeGet!(MessageType);
}

public bool hasTypeGet(MessageType)()
{
	// Alias for the `getType` symbol
	alias member = __traits(getMember, MessageType, "getType");

	// Is a function which takes no arguments and returns an MType
	return isFunction!(member) && arity!(member) == 0 && __traits(isSame, MType, ReturnType!(member));
}

public bool hasPayloadGet(MessageType)()
{
	// Alias for the `getPayload` symbol
	alias member = __traits(getMember, MessageType, "getPayload");

	// Is a function which takes no arguments and returns a ubyte[]
	return isFunction!(member) && arity!(member) == 0 && __traits(isSame, ubyte[], ReturnType!(member));	
}

public bool hasGetTag(MessageType)()
{
	// Alias for the `getTag` symbol
	alias member = __traits(getMember, MessageType, "getTag");

	// Is a function which takes no arguments and returns a Tag
	return isFunction!(member) && arity!(member) == 0 && __traits(isSame, Tag, ReturnType!(member));	
}

unittest
{
	struct F
	{
		
	}
	auto a = F();
	static assert(!__traits(compiles, doEncode(a)));
	// doEncode(a);

	struct F_2
	{
		int encode;
	}
	auto b = F_2();
	static assert(!__traits(compiles, doEncode(b)));
	// doEncode(b);

	struct F_3
	{
		void encode();
	}
	auto c = F_3();
	static assert(!__traits(compiles, doEncode(c)));
	// doEncode(c);

	struct F_4
	{
		ubyte[] encode()
		{
			return [];
		}
	}
	auto d = F_4();
	// FIXME: Move positive test cases ot unittes near the doEncode definition
	// static assert(__traits(compiles, doEncode(d)));
	// doEncode(d);
}

unittest
{
	assert(!__traits(compiles, 1+"d"));;
}

unittest
{
	auto msg = D();

	// isMessage(msg);

	// static assert(__traits(compiles, isMessage(msg)));
}

unittest
{
	auto msg = 1;

	// __traits(compiles, isMessage(msg));
}
