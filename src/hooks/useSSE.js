import { useState, useEffect, useRef } from 'react';
import { createScanStream } from '../lib/api';

export const useSSE = (scanId) => {
  const [data, setData] = useState(null);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState(null);
  const eventSourceRef = useRef(null);
  const retryTimeoutRef = useRef(null);
  const retryCountRef = useRef(0);
  const maxRetries = 5;

  const connect = () => {
    if (!scanId) return;

    try {
      eventSourceRef.current = createScanStream(
        scanId,
        (message) => {
          setData(message);
          setError(null);
          retryCountRef.current = 0; // Reset retry count on successful message
        },
        (err) => {
          console.error('SSE connection error:', err);
          setError(err);
          setIsConnected(false);
          
          // Implement exponential backoff retry
          if (retryCountRef.current < maxRetries) {
            const delay = Math.min(100 * Math.pow(2, retryCountRef.current), 5000);
            retryCountRef.current++;
            
            retryTimeoutRef.current = setTimeout(() => {
              console.log(`Retrying SSE connection (attempt ${retryCountRef.current})`);
              connect();
            }, delay);
          }
        }
      );

      eventSourceRef.current.onopen = () => {
        setIsConnected(true);
        setError(null);
        retryCountRef.current = 0;
      };

    } catch (err) {
      console.error('Failed to create SSE connection:', err);
      setError(err);
    }
  };

  const disconnect = () => {
    if (eventSourceRef.current) {
      eventSourceRef.current.close();
      eventSourceRef.current = null;
    }
    
    if (retryTimeoutRef.current) {
      clearTimeout(retryTimeoutRef.current);
      retryTimeoutRef.current = null;
    }
    
    setIsConnected(false);
  };

  useEffect(() => {
    if (scanId) {
      connect();
    }

    return () => {
      disconnect();
    };
  }, [scanId]);

  // Manual reconnect function
  const reconnect = () => {
    disconnect();
    retryCountRef.current = 0;
    connect();
  };

  return {
    data,
    isConnected,
    error,
    reconnect,
    disconnect
  };
};
