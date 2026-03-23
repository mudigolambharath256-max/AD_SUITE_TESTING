import React, { useEffect, useRef } from 'react';
import cytoscape from 'cytoscape';
import dagre from 'cytoscape-dagre';

// Register the dagre layout
cytoscape.use(dagre);

const BloodHoundGraph = ({ nodes, edges }) => {
    const containerRef = useRef(null);
    const cyRef = useRef(null);

    useEffect(() => {
        if (!containerRef.current || !nodes || nodes.length === 0) return;

        // Destroy existing instance
        if (cyRef.current) {
            cyRef.current.destroy();
        }

        // Map node types to BloodHound-style icons and colors
        const getNodeStyle = (node) => {
            const type = node.type?.toLowerCase() || 'finding';
            const severity = node.severity?.toLowerCase() || 'info';

            const styles = {
                user: {
                    shape: 'ellipse',
                    backgroundColor: '#4A90E2',
                    width: 80,
                    height: 80,
                    label: node.label
                },
                computer: {
                    shape: 'ellipse',
                    backgroundColor: '#E24A4A',
                    width: 80,
                    height: 80,
                    label: node.label
                },
                group: {
                    shape: 'ellipse',
                    backgroundColor: '#50C878',
                    width: 80,
                    height: 80,
                    label: node.label
                },
                domain: {
                    shape: 'ellipse',
                    backgroundColor: '#9B59B6',
                    width: 90,
                    height: 90,
                    label: node.label
                },
                finding: {
                    shape: 'roundrectangle',
                    backgroundColor: getSeverityColor(severity),
                    width: 'label',
                    height: 40,
                    label: node.label
                },
                attack: {
                    shape: 'roundrectangle',
                    backgroundColor: '#E67E22',
                    width: 'label',
                    height: 35,
                    label: node.label
                }
            };

            return styles[type] || styles.finding;
        };

        const getSeverityColor = (severity) => {
            const colors = {
                critical: '#DC2626',
                high: '#EA580C',
                medium: '#F59E0B',
                low: '#10B981',
                info: '#3B82F6'
            };
            return colors[severity] || colors.info;
        };

        // Convert nodes to Cytoscape format
        const cyNodes = nodes.map(node => {
            const style = getNodeStyle(node);
            return {
                data: {
                    id: node.id,
                    label: node.label,
                    type: node.type,
                    severity: node.severity,
                    ...node
                },
                style: {
                    'background-color': style.backgroundColor,
                    'shape': style.shape,
                    'width': style.width,
                    'height': style.height,
                    'label': style.label,
                    'color': '#FFFFFF',
                    'text-valign': 'center',
                    'text-halign': 'center',
                    'font-size': '12px',
                    'font-weight': 'bold',
                    'text-wrap': 'wrap',
                    'text-max-width': '80px',
                    'border-width': 2,
                    'border-color': '#FFFFFF',
                    'border-opacity': 0.3
                }
            };
        });

        // Convert edges to Cytoscape format
        const cyEdges = edges.map((edge, index) => ({
            data: {
                id: `edge-${index}`,
                source: edge.source,
                target: edge.target,
                label: edge.label || ''
            },
            style: {
                'width': 2,
                'line-color': '#666',
                'target-arrow-color': '#666',
                'target-arrow-shape': 'triangle',
                'curve-style': 'bezier',
                'label': edge.label || '',
                'font-size': '10px',
                'color': '#999',
                'text-background-color': '#1a1612',
                'text-background-opacity': 0.8,
                'text-background-padding': '3px'
            }
        }));

        // Initialize Cytoscape
        const cy = cytoscape({
            container: containerRef.current,
            elements: [...cyNodes, ...cyEdges],
            style: [
                {
                    selector: 'node',
                    style: {
                        'overlay-opacity': 0
                    }
                },
                {
                    selector: 'node:selected',
                    style: {
                        'border-width': 3,
                        'border-color': '#F59E0B',
                        'border-opacity': 1
                    }
                },
                {
                    selector: 'edge',
                    style: {
                        'overlay-opacity': 0
                    }
                },
                {
                    selector: 'edge:selected',
                    style: {
                        'line-color': '#F59E0B',
                        'target-arrow-color': '#F59E0B',
                        'width': 3
                    }
                }
            ],
            layout: {
                name: 'dagre',
                rankDir: 'TB',
                nodeSep: 50,
                rankSep: 100,
                padding: 30
            },
            minZoom: 0.3,
            maxZoom: 3,
            wheelSensitivity: 0.2
        });

        // Add interaction handlers
        cy.on('tap', 'node', (evt) => {
            const node = evt.target;
            console.log('Node clicked:', node.data());
        });

        cy.on('tap', 'edge', (evt) => {
            const edge = evt.target;
            console.log('Edge clicked:', edge.data());
        });

        // Fit to viewport
        cy.fit(50);

        cyRef.current = cy;

        // Cleanup
        return () => {
            if (cyRef.current) {
                cyRef.current.destroy();
            }
        };
    }, [nodes, edges]);

    return (
        <div
            ref={containerRef}
            style={{
                width: '100%',
                height: '100%',
                backgroundColor: '#1a1612',
                borderRadius: '8px',
                border: '1px solid #3d3530'
            }}
        />
    );
};

export default BloodHoundGraph;
