module ninepee.manager;

import ninepee.client;
import ninepee.message;
import std.string : format;

// Client remote endpoint I/O ops
public interface RemoteEndpoint
{
	public ptrdiff_t read(ubyte[] into); 
	public ptrdiff_t write(ubyte[] from); // TODO: ret written bytes?
}

import core.thread;
import niknaks.arrays : isPresent;

private struct ClientState
{
	private Tag tag;
	
}

import std.datetime.systime : SysTime, Clock;

private struct FidRecord
{
	private Fid f;
	private SysTime created;
	this(Fid f)
	{
		this.f = f;
		this.created = Clock.currTime();
	}
	// uname, aname?
	// idk what else really

	public SysTime creationTime()
	{
		return this.created;
	}
	
	public Duration elapsed()
	{
		return Clock.currTime()-this.created;
	}

	public Fid fid()
	{
		return this.fid;
	}

	public bool opEquals(FidRecord rhs)
	{
		return this.fid == rhs.fid();
	}
}

public struct RemoteClient
{
	// TODO: Add multi-tag management to a single client
	
	private Server s;
	private Thread t;
	private RemoteEndpoint io;
	private FidRecord[] opened;

	private string uname;

	// Protocol decoder
	private Client c;

	private this(Server s, RemoteEndpoint io)
	{
		this.s = s;
		this.io = io;
		this.t = new Thread(&reader);
		this.t.start();
	}

	private bool isFidAvailable(Fid wanted)
	{
		// FidRecords are comparable by their Fids
		return !isPresent(this.opened, FidRecord(wanted));
	}

	private void addFid(FidRecord f)
	{
		this.opened ~= f;
	}

	private bool handshake()
	{
		Message m;

		writeln("handshake read() begin");
		if(!doRead(m))
		{
			writeln("Failed during handshale");
			return false;
		}
		writeln("handshake read() end");

		VersionMessage_V2 v = cast(VersionMessage_V2)m;
		if(!v)
		{
			writeln("Was expecting a Tversion messahe during handshake but got: ", m);
			return false;
		}


		// TODO: Process version here
		string wanted = v.getVersion();
		uint msizeWanted = v.getMSize();
		writeln(format("Remote client wants version '%s' with max size of '%s'", wanted, msizeWanted));

		// TODO: For now reply with the same things
		VersionMessage_V2 vr = VersionMessage_V2.makeReply(msizeWanted, wanted);
		vr.setTag(v.getTag());

		io.write(vr.encode());
		return true;
	}

	private bool isAttached = false;

	// TODO: Handle fatal errors
	// by ending and removing ourselves
	// from the server
	private void reader()
	{
		// Negotiate version
		if(!handshake())
		{
			writeln("Handshaking failed.");
			return;
		}

		// Main loop
		loop();
	}

	private void loop()
	{
		Message m;
		
		lp: while(true)
		{
			dbg();

			if(!doRead(m))
			{
				// TODO: parse error may NOT be fata;
				writeln("reading failed, either transport is bad or parse error");
				break;
			}
			
			// if you are attached
			if(isAttached)
			{
				
			}
			// if unattached
			else
			{
				// TODO: Add auth support later
				
				AttachMessage am = cast(AttachMessage)m;
				if(am)
				{
					writeln("Can haz attach?");

					// If auth is wanted
					if(am.wantsAuth())
					{
						errToClient(m.getTag(), format("Authentication was requested with afid '%d' but we don't support auth yet"));
						continue lp;
					}
					
					
					// Try allocate fid
					Fid fidReq = am.getFid();
					writeln(format("New session requested fid '%d'", fidReq));
					if(!isFidAvailable(fidReq))
					{
						errToClient(m.getTag(), format("Requested fid %d but already in use", fidReq));
						continue lp;
					}

					// now request server lookup (TODO: handle res)
					Qid qid;
					auto res = s.attach0(am.getUser(), am.getFileTree(), qid);
					writeln("attachmet res: ", res);
					if(res)
					{
						FidRecord fidRec = Fid(fidReq);
						addFid(fidRec);
						AttachMessage r = AttachMessage.makeReply(qid);
					}
					else
					{
						errToClient(m.getTag(), format("Failure to attach to %s: %s", am.getFileTree(), res));
					}
				}
				else
				{
					errToClient(m.getTag(), format("Not currently attached, cannot handle message '%s'", m));
				}
			}
		}

		writeln("loop end");
	}

	private void errToClient(Tag tag, string s)
	{
		writeln(s);
		ErrorMessage e = ErrorMessage.errorFor(tag, s);
		io.write(e.encode());
	}

	private void dbg()
	{
		
	}


	private bool doRead(ref Message m)
	{
		ubyte[] o;
		
		// Read 1 byte (TODO: Handle c <= 0)
		o.length = 1;
		writeln("doRead(): Waiting for first byte");
		ptrdiff_t cnt = io.read(o);

		if(cnt <= 0)
		{
			writeln("doRead(): cnt<=0 for first byte");
			return false;
		}

		ParseResult res = c.recv(o);

		writeln("prior to lp");

		while(res.getStatus() == ParseStatus.NEEDS_MORE_DATA)
		{
			writeln("iter: status: ", res.getStatus());

			// Try read the remaining bytes needed
			o.length = res.getRemaining();
			writeln("rem wanted: ", o.length);
			cnt = io.read(o);
			writeln("cnt (got): ", cnt);
			writeln("arr after io.read(): ", o);

			if(cnt <= 0)
			{
				writeln("doRead(): cnt<=0 for first byte");
				return false;
			}
			writeln("here");

			// Trim (to not push bad trailing data when cnt<o.length)
			o.length = cnt;
			writeln(o.length);
			res = c.recv(o);
		}

		writeln("after lp");

		if(res.getStatus() == ParseStatus.OKAY)
		{
			m = res.getMessage();
			writeln("doRead(): Got message ", m);
			return true;
		}
		else
		{
			writeln("doRead(): Transport IO is FINE but message parsing failed");
			return true;
		}
	}
}

alias RemoteID = size_t;

public interface Auth
{
	
}

private Qid bogusQid()
{
	
}

public class Server
{
	import core.sync.mutex : Mutex;
	
	// TODO: mutex protect me
	private RemoteClient[RemoteID] clients;
	private Mutex clientsLock;

	this(string ver = "9P2000")
	{
		this.clientsLock = new Mutex();
	}

	// private bool findNextFree

	public bool addClient(RemoteEndpoint endpoint, ref RemoteID cid)
	{
		this.clientsLock.lock();

		scope(exit)
		{
			this.clientsLock.unlock();
		}

		return true;
	}

	public bool removeClient(RemoteID cid)
	{
		this.clientsLock.lock();
		
		scope(exit)
		{
			this.clientsLock.unlock();
		}

		return true;
	}

	// TODO: use result type rather
	public bool attach0(string uname, string aname, ref Qid qid)
	{
		writeln(format("User %s is requesting access to file tree '%aname'", uname, aname));

		// TODO: Generate a unique qid shits

		return true;
	}
}

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

public class TCPIO : RemoteEndpoint
{
	private Socket s;
	this(Socket s)
	{
		this.s = s;
	}
	
	public ptrdiff_t read(ubyte[] into)
	{
		writeln("RRR");
		auto wnt = into.length;
		auto got = s.receive(into);
		writeln("sock read() wnt: ", wnt, ", got: ", got);
		return got;
	}
	public ptrdiff_t write(ubyte[] from)
	{
		return s.send(from);
	}
}

unittest
{
	Socket serv = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
	serv.bind(parseAddress("127.0.0.1", 2222));
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

	Server s = new Server();
	RemoteClient cn = RemoteClient(s, new TCPIO(client));

	import core.thread;
	while(!(s is null))
	{
		Thread.sleep(dur!("seconds")(5));
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
