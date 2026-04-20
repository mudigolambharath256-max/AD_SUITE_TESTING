/**
 * Tunable parameters for AD entity graph visualization (Cytoscape).
 * Adjust here without touching component wiring.
 */
export const GRAPH_VIZ_CONFIG = {
    /** Zoom level above which routine node labels appear (LOD). */
    labelZoomThreshold: 0.55,
    /** Debounce for zoom-driven style passes (ms). */
    zoomLodDebounceMs: 48,
    layout: {
        /** Switch to faster settings when node count exceeds this. */
        largeGraphNodeThreshold: 2500,
        cose: {
            name: 'cose' as const,
            animate: true,
            animationDuration: 700,
            animationEasing: 'ease-out-cubic',
            fit: true,
            padding: 88,
            randomize: true,
            componentSpacing: 200,
            nodeRepulsion: () => 2.8e6,
            idealEdgeLength: () => 300,
            edgeElasticity: () => 0.2,
            nestingFactor: 0.1,
            gravity: 0.05,
            numIter: 5200,
            initialTemp: 1200,
            coolingFactor: 0.93,
            minTemp: 0.45,
            refresh: 24,
            nodeOverlap: 48,
            nodeDimensionsIncludeLabels: true
        },
        coseLarge: {
            name: 'cose' as const,
            animate: false,
            fit: true,
            padding: 64,
            randomize: false,
            componentSpacing: 120,
            nodeRepulsion: () => 1.2e6,
            idealEdgeLength: () => 180,
            edgeElasticity: () => 0.25,
            nestingFactor: 0.08,
            gravity: 0.08,
            numIter: 1600,
            minTemp: 1,
            coolingFactor: 0.95,
            refresh: 40,
            nodeOverlap: 32,
            nodeDimensionsIncludeLabels: false
        }
    },
    /** After layout, nudge Y by tier band (pixels) for analyst-friendly layering. */
    tierBandNudgePx: 56,
    /** Minimum nodes per domain to create a compound parent (reduces noise for single-domain forests). */
    minNodesForDomainCompound: 1,
    viewport: {
        minZoom: 0.08,
        maxZoom: 3.4,
        wheelSensitivity: 0.16
    },
    /** Relationships treated as high-value / attack-relevant for highlighting. */
    attackPathRels: new Set(
        [
            'MemberOf',
            'DCSync',
            'Kerberoast',
            'ASREPRoast',
            'HasSPN',
            'HasShadowCredentials',
            'AllowedToAct(RBCD)',
            'LinkedTo',
            'GenericAll',
            'GenericWrite',
            'WriteOwner',
            'WriteDacl',
            'Owns',
            'Contains',
            'GpLink',
            'Enroll',
            'PublishedBy',
            'ProtectedUser(adminCount=1)',
            'ReversibleEncryptionEnabled'
        ].map((s) => s.toLowerCase())
    ),
    kerberosRels: new Set(
        ['kerberoast', 'as-reproast', 'hasspn', 'dcsync'].map((s) => s.toLowerCase())
    ),
    /** Low-priority edges (dimmed unless highlighted). */
    lowPriorityRels: new Set(['samefinding', 'inscope'].map((s) => s.toLowerCase()))
} as const;

export type GraphVizConfig = typeof GRAPH_VIZ_CONFIG;
