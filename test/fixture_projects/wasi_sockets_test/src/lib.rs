#[allow(warnings)]
mod bindings;

use bindings::Guest;
use wasi::sockets::network::IpAddressFamily;
use wasi::sockets::tcp_create_socket::create_tcp_socket;
use wasi::sockets::tcp::IpSocketAddress;
use wasi::sockets::ip_name_lookup::resolve_addresses;

struct Component;

impl Guest for Component {
    fn test_dns_lookup(host: String) -> Result<String, String> {
        // Get the default network
        let network = wasi::sockets::instance_network::instance_network();

        // Resolve the hostname
        let stream = resolve_addresses(&network, &host)
            .map_err(|e| format!("Failed to resolve hostname: {:?}", e))?;

        // Get the first address
        let address = stream.resolve_next_address()
            .map_err(|e| format!("Failed to get resolved addresses: {:?}", e))?;

        match address {
            Some(wasi::sockets::network::IpAddress::Ipv4(addr)) => {
                Ok(format!("{}.{}.{}.{}", addr.0, addr.1, addr.2, addr.3))
            }
            Some(wasi::sockets::network::IpAddress::Ipv6(addr)) => {
                Ok(format!("IPv6: {:x?}", addr))
            }
            None => Err("No addresses resolved".to_string())
        }
    }

    fn test_tcp_connect(host: String, port: u16) -> Result<String, String> {
        // Get the default network
        let network = wasi::sockets::instance_network::instance_network();

        // Create a TCP socket
        let socket = create_tcp_socket(IpAddressFamily::Ipv4)
            .map_err(|e| format!("Failed to create socket: {:?}", e))?;

        // First resolve the hostname
        let stream = resolve_addresses(&network, &host)
            .map_err(|e| format!("Failed to resolve hostname: {:?}", e))?;

        // Get the first address
        let ip_address = stream.resolve_next_address()
            .map_err(|e| format!("Failed to get resolved addresses: {:?}", e))?
            .ok_or_else(|| "No addresses resolved".to_string())?;

        // Convert to socket address
        let socket_address = match ip_address {
            wasi::sockets::network::IpAddress::Ipv4(ipv4) => {
                IpSocketAddress::Ipv4(wasi::sockets::network::Ipv4SocketAddress {
                    address: ipv4,
                    port,
                })
            }
            wasi::sockets::network::IpAddress::Ipv6(_addr) => {
                return Err("IPv6 not implemented in this test".to_string());
            }
        };

        // Try to start connecting (non-blocking)
        socket.start_connect(&network, socket_address)
            .map_err(|e| format!("Failed to start connection: {:?}", e))?;

        // Successfully initiated connection
        Ok(format!("Successfully initiated TCP connection to {}:{}", host, port))
    }
}

bindings::export!(Component with_types_in bindings);
