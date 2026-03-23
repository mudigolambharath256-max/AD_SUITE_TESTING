import React, { useEffect, useRef, useState } from 'react';
import mermaid from 'mermaid';

// Initialize mermaid with dark theme and custom colors
mermaid.initialize({
    startOnLoad: false,
    theme: 'base',
    themeVariables: {
        darkMode: true,
        background: '#1a1612',
        primaryColor: '#4A90E2',
        primaryTextColor: '#fff',
        primaryBorderColor: '#4A90E2',
        lineColor: '#666',
        secondaryColor: '#E24A4A',
        tertiaryColor: '#50C878',
        fontSize: '14px',
        fontFamily: 'ui-sans-serif, system-ui, sans-serif',
        // Node colors
        nodeBorder: '#666',
        mainBkg: '#2a2420',
        textColor: '#F5F1ED',
        // Edge colors
        edgeLabelBackground: '#1a1612',
        clusterBkg: '#2a2420',
        clusterBorder: '#666'
    },
    flowchart: {
        useMaxWidth: true,
        htmlLabels: true,
        curve: 'basis',
        padding: 20
    }
});

const MermaidGraph = ({ chart, findings = [], onNodeClick }) => {
    const containerRef = useRef(null);
    const [selectedNode, setSelectedNode] = useState(null);
    const [nodeFindings, setNodeFindings] = useState([]);
    const [zoom, setZoom] = useState(1);

    useEffect(() => {
        if (!chart || !containerRef.current) return;

        const renderChart = async () => {
            try {
                // Clear previous content
                containerRef.current.innerHTML = '';

                // Generate unique ID for this render
                const id = `mermaid-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

                // Render the chart
                const { svg } = await mermaid.render(id, chart);

                // Insert the SVG
                containerRef.current.innerHTML = svg;

                // Fix SVG sizing and viewBox
                const svgElement = containerRef.current.querySelector('svg');
                if (svgElement) {
                    svgElement.style.width = '100%';
                    svgElement.style.height = '100%';
                    svgElement.style.maxWidth = '100%';
                    svgElement.removeAttribute('width');
                    svgElement.removeAttribute('height');

                    // Get the viewBox or create one
                    let viewBox = svgElement.getAttribute('viewBox');
                    if (!viewBox) {
                        const bbox = svgElement.getBBox();
                        viewBox = `${bbox.x - 20} ${bbox.y - 20} ${bbox.width + 40} ${bbox.height + 40}`;
                        svgElement.setAttribute('viewBox', viewBox);
                    }

                    svgElement.setAttribute('preserveAspectRatio', 'xMidYMid meet');

                    // Apply zoom
                    svgElement.style.transform = `scale(${zoom})`;
                    svgElement.style.transformOrigin = 'center center';
                }

                // Add click handlers to nodes
                const nodes = containerRef.current.querySelectorAll('.node');
                nodes.forEach(node => {
                    node.style.cursor = 'pointer';
                    node.style.transition = 'opacity 0.2s';

                    // Add hover effect - only change opacity, no transform
                    node.addEventListener('mouseenter', () => {
                        node.style.opacity = '0.7';
                    });

                    node.addEventListener('mouseleave', () => {
                        node.style.opacity = '1';
                    });

                    node.addEventListener('click', (e) => {
                        e.stopPropagation();

                        // Get node label text
                        const labelElement = node.querySelector('.nodeLabel, text');
                        const nodeLabel = labelElement ? labelElement.textContent.trim() : '';

                        // Find related findings based on node label
                        const relatedFindings = findRelatedFindings(nodeLabel, findings);

                        setSelectedNode(nodeLabel);
                        setNodeFindings(relatedFindings);

                        if (onNodeClick) {
                            onNodeClick(nodeLabel, relatedFindings);
                        }
                    });
                });
            } catch (error) {
                console.error('Mermaid rendering error:', error);
                containerRef.current.innerHTML = `
          <div style="color: #DC2626; padding: 20px; text-align: center;">
            <p>Failed to render diagram</p>
            <p style="font-size: 12px; color: #999; margin-top: 10px;">${error.message}</p>
          </div>
        `;
            }
        };

        renderChart();
    }, [chart, findings, onNodeClick, zoom]);

    const findRelatedFindings = (nodeLabel, allFindings) => {
        if (!nodeLabel || !allFindings || allFindings.length === 0) return [];

        const cleanLabel = nodeLabel.toLowerCase().replace(/['"]/g, '').trim();

        return allFindings.filter(finding => {
            const searchableText = `
        ${finding.name || ''} 
        ${finding.checkName || ''} 
        ${finding.category || ''} 
        ${finding.description || ''}
        ${finding.distinguishedName || ''}
      `.toLowerCase();

            // Strategy 1: Direct substring match (e.g., "sansa.stark" in "sansa.stark Cracked")
            if (searchableText.includes(cleanLabel)) return true;

            // Strategy 2: Check if finding name is in the node label
            const findingName = (finding.name || '').toLowerCase();
            if (findingName && cleanLabel.includes(findingName)) return true;

            // Strategy 3: Split node label and check each part (min 3 chars to avoid false positives)
            const labelParts = cleanLabel.split(/\s+/).filter(part => part.length >= 3);
            for (const part of labelParts) {
                // Check if this part appears in searchable text
                if (searchableText.includes(part)) return true;

                // Also check with dots replaced by spaces (e.g., "sansa.stark" -> "sansa stark")
                const partWithSpaces = part.replace(/\./g, ' ');
                if (partWithSpaces !== part && searchableText.includes(partWithSpaces)) return true;
            }

            // Strategy 4: Check for attack technique keywords
            const attackKeywords = ['asrep', 'kerberoast', 'delegation', 'dcsync', 'admin', 'privileged', 'unconstrained'];
            for (const keyword of attackKeywords) {
                if (cleanLabel.includes(keyword) && searchableText.includes(keyword)) return true;
            }

            return false;
        });
    };

    const getSeverityColor = (severity) => {
        const colors = {
            CRITICAL: '#DC2626',
            HIGH: '#EA580C',
            MEDIUM: '#F59E0B',
            LOW: '#10B981',
            INFO: '#3B82F6'
        };
        return colors[severity?.toUpperCase()] || colors.INFO;
    };

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', height: '100%', width: '100%' }}>
            {/* Zoom Controls */}
            <div style={{
                display: 'flex',
                gap: '10px',
                justifyContent: 'center',
                padding: '10px',
                backgroundColor: '#2a2420',
                borderRadius: '8px',
                border: '1px solid #3d3530'
            }}>
                <button
                    onClick={() => setZoom(z => Math.min(z + 0.2, 3))}
                    style={{
                        backgroundColor: '#3d3530',
                        color: '#F5F1ED',
                        border: '1px solid #4d4540',
                        padding: '8px 16px',
                        borderRadius: '6px',
                        cursor: 'pointer',
                        fontSize: '14px',
                        fontWeight: '500'
                    }}
                >
                    🔍 Zoom In
                </button>
                <button
                    onClick={() => setZoom(z => Math.max(z - 0.2, 0.5))}
                    style={{
                        backgroundColor: '#3d3530',
                        color: '#F5F1ED',
                        border: '1px solid #4d4540',
                        padding: '8px 16px',
                        borderRadius: '6px',
                        cursor: 'pointer',
                        fontSize: '14px',
                        fontWeight: '500'
                    }}
                >
                    🔍 Zoom Out
                </button>
                <button
                    onClick={() => setZoom(1)}
                    style={{
                        backgroundColor: '#3d3530',
                        color: '#F5F1ED',
                        border: '1px solid #4d4540',
                        padding: '8px 16px',
                        borderRadius: '6px',
                        cursor: 'pointer',
                        fontSize: '14px',
                        fontWeight: '500'
                    }}
                >
                    ↺ Reset Zoom
                </button>
                <span style={{
                    color: '#C9BFB5',
                    padding: '8px 16px',
                    fontSize: '14px',
                    display: 'flex',
                    alignItems: 'center'
                }}>
                    {Math.round(zoom * 100)}%
                </span>
            </div>

            <div style={{ display: 'flex', gap: '20px', flex: 1, minHeight: 0 }}>
                {/* Mermaid Diagram */}
                <div
                    ref={containerRef}
                    style={{
                        flex: selectedNode ? '0 0 60%' : '1',
                        overflow: 'auto',
                        backgroundColor: '#1a1612',
                        borderRadius: '8px',
                        border: '1px solid #3d3530',
                        padding: '20px',
                        transition: 'flex 0.3s ease',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        minHeight: '400px'
                    }}
                    className="mermaid-container"
                />

                {/* Findings Panel */}
                {selectedNode && (
                    <div
                        style={{
                            flex: '0 0 38%',
                            backgroundColor: '#1a1612',
                            borderRadius: '8px',
                            border: '1px solid #3d3530',
                            padding: '20px',
                            overflow: 'auto',
                            animation: 'slideIn 0.3s ease'
                        }}
                    >
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
                            <h4 style={{ color: '#F5F1ED', margin: 0, fontSize: '16px', fontWeight: '600' }}>
                                Node Details
                            </h4>
                            <button
                                onClick={() => {
                                    setSelectedNode(null);
                                    setNodeFindings([]);
                                }}
                                style={{
                                    background: 'transparent',
                                    border: 'none',
                                    color: '#999',
                                    cursor: 'pointer',
                                    fontSize: '20px',
                                    padding: '0',
                                    width: '24px',
                                    height: '24px'
                                }}
                            >
                                ×
                            </button>
                        </div>

                        <div style={{
                            backgroundColor: '#2a2420',
                            padding: '12px',
                            borderRadius: '6px',
                            marginBottom: '15px',
                            borderLeft: '3px solid #4A90E2'
                        }}>
                            <div style={{ color: '#F5F1ED', fontWeight: '500', fontSize: '14px' }}>
                                {selectedNode}
                            </div>
                        </div>

                        <h5 style={{ color: '#C9BFB5', fontSize: '14px', marginBottom: '10px', fontWeight: '600' }}>
                            Related Findings ({nodeFindings.length})
                        </h5>

                        {nodeFindings.length === 0 ? (
                            <div style={{ color: '#999', fontSize: '13px', fontStyle: 'italic', padding: '20px', textAlign: 'center' }}>
                                No findings directly related to this node
                            </div>
                        ) : (
                            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                                {nodeFindings.map((finding, index) => (
                                    <div
                                        key={index}
                                        style={{
                                            backgroundColor: '#2a2420',
                                            padding: '12px',
                                            borderRadius: '6px',
                                            borderLeft: `3px solid ${getSeverityColor(finding.severity)}`
                                        }}
                                    >
                                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '8px' }}>
                                            <div style={{ color: '#F5F1ED', fontSize: '13px', fontWeight: '500', flex: 1 }}>
                                                {finding.checkName || finding.name}
                                            </div>
                                            <span
                                                style={{
                                                    backgroundColor: getSeverityColor(finding.severity),
                                                    color: 'white',
                                                    padding: '2px 8px',
                                                    borderRadius: '4px',
                                                    fontSize: '11px',
                                                    fontWeight: '600',
                                                    marginLeft: '8px'
                                                }}
                                            >
                                                {finding.severity}
                                            </span>
                                        </div>

                                        {finding.name && (
                                            <div style={{ color: '#C9BFB5', fontSize: '12px', marginBottom: '4px' }}>
                                                <strong>Object:</strong> {finding.name}
                                            </div>
                                        )}

                                        {finding.category && (
                                            <div style={{ color: '#999', fontSize: '11px', marginBottom: '4px' }}>
                                                <strong>Category:</strong> {finding.category.replace(/_/g, ' ')}
                                            </div>
                                        )}

                                        {finding.mitre && (
                                            <div style={{ color: '#999', fontSize: '11px', marginBottom: '4px' }}>
                                                <strong>MITRE:</strong> {finding.mitre}
                                            </div>
                                        )}

                                        {finding.description && (
                                            <div style={{ color: '#999', fontSize: '11px', marginTop: '8px', lineHeight: '1.4' }}>
                                                {finding.description}
                                            </div>
                                        )}
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                )}
            </div>

            <style>{`
        @keyframes slideIn {
          from {
            opacity: 0;
            transform: translateX(20px);
          }
          to {
            opacity: 1;
            transform: translateX(0);
          }
        }
        
        .mermaid-container svg {
          max-width: 100%;
          max-height: 100%;
          width: auto !important;
          height: auto !important;
        }
        
        .mermaid-container {
          overflow: visible !important;
        }
        
        .mermaid-container .node:hover {
          filter: brightness(1.2);
          cursor: pointer;
        }
        
        .mermaid-container .node:active {
          filter: brightness(0.9);
        }
      `}</style>
        </div>
    );
};

export default MermaidGraph;
