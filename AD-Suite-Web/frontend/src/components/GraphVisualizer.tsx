
import { SigmaContainer, ControlsContainer, ZoomControl, FullScreenControl } from '@react-sigma/core';
import "@react-sigma/core/lib/style.css";
import Graph from 'graphology';

interface GraphVisualizerProps {
    data: {
        nodes: { id: string, label: string, color: string, size: number }[];
        edges: { id: string, source: string, target: string, label: string }[];
    };
}

export function GraphVisualizer({ data }: GraphVisualizerProps) {
    const graph = new Graph();

    data.nodes.forEach(node => {
        if (!graph.hasNode(node.id)) {
            graph.addNode(node.id, { ...node, x: Math.random() * 10, y: Math.random() * 10 });
        }
    });
    data.edges.forEach(edge => {
        if (!graph.hasEdge(edge.id) && graph.hasNode(edge.source) && graph.hasNode(edge.target)) {
            graph.addEdgeWithKey(edge.id, edge.source, edge.target, { type: 'arrow', label: edge.label, size: 2 });
        }
    });

    return (
        <div style={{ height: '600px', width: '100%' }} className="bg-gray-900 rounded-lg overflow-hidden border border-gray-700 mt-4">
            <SigmaContainer graph={graph} style={{ height: "100%", width: "100%" }}>
                <ControlsContainer position={"bottom-right"}>
                    <ZoomControl />
                    <FullScreenControl />
                </ControlsContainer>
                <ControlsContainer position={"top-left"}>
                    
                </ControlsContainer>
            </SigmaContainer>
        </div>
    );
}

export default GraphVisualizer;
