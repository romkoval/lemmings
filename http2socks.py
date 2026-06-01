#!/usr/bin/env python3
"""Tiny HTTP→SOCKS5 proxy for Claude Code (Node.js doesn't support SOCKS5 in http_proxy)."""
import asyncio
import sys
from python_socks.async_.asyncio import Proxy
from python_socks import ProxyType

async def handle_client(reader, writer):
    try:
        # Read first line to know where to connect
        data = await reader.readuntil(b'\r\n\r\n')
        first_line = data.split(b'\r\n')[0].decode()
        
        if first_line.startswith('CONNECT'):
            # HTTPS CONNECT tunnel
            target = first_line.split()[1]  # host:port
            host, port = target.split(':')
            port = int(port)
            
            proxy = Proxy(ProxyType.SOCKS5, '127.0.0.1', 52246)
            sock = await proxy.connect(dest_host=host, dest_port=port)
            
            writer.write(b'HTTP/1.1 200 Connection Established\r\n\r\n')
            await writer.drain()
            
            # Bidirectional relay (raw TCP)
            async def relay(src, dst):
                try:
                    while True:
                        chunk = await src.read(8192)
                        if not chunk:
                            break
                        dst.write(chunk)
                        await dst.drain()
                except:
                    pass
            
            # Wrap the socket
            remote_reader, remote_writer = await asyncio.open_connection(sock=sock)
            
            await asyncio.gather(
                relay(reader, remote_writer),
                relay(remote_reader, writer),
            )
        else:
            writer.write(b'HTTP/1.1 500 Only CONNECT supported\r\n\r\n')
            await writer.drain()
    except Exception as e:
        try:
            writer.write(f'HTTP/1.1 502 Bad Gateway\r\n\r\n{str(e)}\r\n'.encode())
            await writer.drain()
        except:
            pass
    finally:
        try:
            writer.close()
        except:
            pass

async def main(host, port):
    server = await asyncio.start_server(handle_client, host, port)
    print(f'HTTP→SOCKS5 proxy on {host}:{port}', flush=True)
    async with server:
        await server.serve_forever()

if __name__ == '__main__':
    host = sys.argv[1] if len(sys.argv) > 1 else '127.0.0.1'
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 3128
    asyncio.run(main(host, port))
