module ninepee.manager;

import ninepee.client;
import ninepee.message;

// TODO: Remove testing code
version(unittest)
{
	import std.socket;
	import std.stdio;
}

unittest
{
	Client c;

	auto i = c.recv
	(
		[
			21, 0, 0, 0,
			100, 255, 255, 24,
			0, 2, 0, 8,
			0, 57, 80, 50,
			48, 48, 48, 46,
			76
		]
	);

	writeln("Res: ", i.getStatus());
	writeln("Res LEKKEKR: ", i.getMessage());
}

unittest
{
	Socket serv = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
	serv.bind(parseAddress("127.0.0.1", 2227));
	serv.listen(0);

	Tag tagToUse;

	Socket client = serv.accept();

	scope(exit)
	{
		import std.stdio;
		client.shutdown(SocketShutdown.BOTH);
		client.close();
		serv.shutdown(SocketShutdown.BOTH);
		serv.close();
		writeln("hi");
	}


	Client c;
	
	ubyte[] o;
	o.length = 1;
	client.receive(o);
	
	ParseResult res = c.recv(o);
	
	
	while(res.getStatus() == ParseStatus.NEEDS_MORE_DATA)
	{
		o.length = res.getRemaining();
		auto i = client.receive(o);
		o.length = i;
		res = c.recv(o);
	}

	assert(res.getStatus() == ParseStatus.OKAY);

	Message got = res.getMessage();
	writeln("SOCKET RESULT: ", got);
	// use this tag from here on out
	tagToUse = got.getTag();

	import core.thread;
	Thread.sleep(dur!("seconds")(10));

	VersionMessage_V2 openingMsg = cast(VersionMessage_V2)got;

	// Send version reply?
	Message back = VersionMessage_V2.makeReply(openingMsg.getMSize(), openingMsg.getVersion());
	back.setTag(cast(Tag)-1);
	client.send(back.encode());

	

	while(true)
	{
			o.length = 1;
			client.receive(o);
			
			 res = c.recv(o);
			
			
			while(res.getStatus() == ParseStatus.NEEDS_MORE_DATA)
			{
				o.length = res.getRemaining();
				auto i = client.receive(o);
				o.length = i;
				res = c.recv(o);
			}
		
			assert(res.getStatus() == ParseStatus.OKAY);
		
			 got = res.getMessage();
			writeln("SOCKET RESULT: ", got);
	}
}
