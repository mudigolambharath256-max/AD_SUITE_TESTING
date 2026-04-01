/**
 * Deterministic layout for kill-chain finding paths (per-chain horizontal rows).
 * Node ids are `${chainIndex}-${stepIndex}` so repeated findingIds in one chain stay distinct.
 */

export type KillChainStep = { findingId: string; attackerAction: string };

export type KillChainInput = {
    title?: string;
    chain?: string;
    steps?: KillChainStep[] | undefined;
};

export type PlacedNode = {
    id: string;
    chainIndex: number;
    stepIndex: number;
    label: string;
    x: number;
    y: number;
};

export type PlacedLink = {
    id: string;
    source: string;
    target: string;
    label: string;
    x1: number;
    y1: number;
    x2: number;
    y2: number;
};

export type ChainBand = {
    chainIndex: number;
    title: string;
    titleY: number;
    nodeY: number;
};

export type KillChainLayout = {
    nodes: PlacedNode[];
    links: PlacedLink[];
    bands: ChainBand[];
    width: number;
    height: number;
};

const PADDING = 20;
const TITLE_ROW = 24;
const NODE_R = 26;
/** Space below circle for finding label */
const LABEL_BELOW = 18;
const BAND_GAP = 24;

function bandHeight(): number {
    return TITLE_ROW + NODE_R * 2 + LABEL_BELOW + BAND_GAP;
}

/**
 * Build node/link positions for SVG rendering. Returns null if there is nothing to draw.
 */
export function buildKillChainLayout(
    killChains: KillChainInput[] | undefined,
    width: number
): KillChainLayout | null {
    if (!killChains?.length || width < 80) return null;

    const prepared = killChains
        .map((kc, chainIndex) => ({
            kc,
            chainIndex,
            steps: (kc.steps ?? []).filter((s) => s && String(s.findingId ?? '').trim())
        }))
        .filter((x) => x.steps.length > 0);

    if (!prepared.length) return null;

    const nodes: PlacedNode[] = [];
    const links: PlacedLink[] = [];
    const bands: ChainBand[] = [];

    let rowTop = PADDING;

    for (const { kc, chainIndex, steps } of prepared) {
        const title = kc.title?.trim() || `Chain ${chainIndex + 1}`;
        const titleY = rowTop + 16;
        const nodeY = rowTop + TITLE_ROW + NODE_R;

        bands.push({ chainIndex, title, titleY, nodeY });

        const n = steps.length;
        const left = PADDING;
        const right = width - PADDING;

        for (let si = 0; si < n; si++) {
            const id = `${chainIndex}-${si}`;
            const x =
                n === 1
                    ? width / 2
                    : left + (si / (n - 1)) * (right - left);
            const label = String(steps[si].findingId).trim();
            nodes.push({ id, chainIndex, stepIndex: si, label, x, y: nodeY });
        }

        const nodeById = new Map(nodes.filter((nd) => nd.chainIndex === chainIndex).map((nd) => [nd.id, nd]));

        for (let si = 0; si < n - 1; si++) {
            const source = `${chainIndex}-${si}`;
            const target = `${chainIndex}-${si + 1}`;
            const a = nodeById.get(source);
            const b = nodeById.get(target);
            if (!a || !b) continue;
            const raw = String(steps[si + 1]?.attackerAction ?? '').trim();
            const label = raw || 'next';
            links.push({
                id: `${source}->${target}`,
                source,
                target,
                label,
                x1: a.x,
                y1: a.y,
                x2: b.x,
                y2: b.y
            });
        }

        rowTop += bandHeight();
    }

    const height = Math.max(rowTop + PADDING, 120);

    return {
        nodes,
        links,
        bands,
        width,
        height
    };
}
