module ninepee.message;

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
	// Obtain the encoded message (from tag[2] onwards)
	ubyte[] sub = message.encode();
	writeln("sub bytes below:");
	version(DBG_ARR_DUMPS) { writeln(dumpArray!(sub)()); }

	// Calculate total length as size[4] type[1] sub[sub.length]
	uint len = cast(uint)(4+1+sub.length);
	writeln(format("total 9p msg len is: %d bytes", len));
}

unittest
{
	struct Ting
	{
		
	
		ubyte[] encode()
		{
			return [66, 65, 65, 66];
		}
	}

	auto msg = Ting();
	doEncode(msg);
}

import std.traits;

public bool isMessage(MessageType)()
{
	// Needs to have a member named `encode`
	if(!hasMember!(MessageType, "encode"))
	{
		return false;
	}

	// Alias for the encode symbol
	alias member = __traits(getMember, MessageType, "encode");

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
	return hasTagGet!(MessageType);
}

public bool hasTagGet(MessageType)()
{
	// Alias for the `getTag` symbol
	alias member = __traits(getMember, MessageType, "getTag");

	// Is a function which takes no arguments and returns a ubyte
	return isFunction!(member) && arity!(member) == 0 && __traits(isSame, ubyte, ReturnType!(member));
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
	static assert(__traits(compiles, doEncode(d)));
	doEncode(d);
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
