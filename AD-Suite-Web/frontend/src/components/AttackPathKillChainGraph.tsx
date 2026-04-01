import { useEffect, useRef, useState } from 'react';
import * as d3 from 'd3';
import {
    buildKillChainLayout,
    type KillChainInput
} from '../lib/attackPathKillChainGraph';

const ACCENT = '#f97316';
const EDGE = '#64748b';
const TEXT = '#e2e8f0';
const MUTED = '#94a3b8';
const BG = '#0b1220';

type Props = {
    killChains: KillChainInput[] | undefined;
    className?: string;
    /** Taller min area when parent is fullscreen */
    isFullscreen?: boolean;
};

function truncate(s: string, max: number): string {
    if (s.length <= max) return s;
    return `${s.slice(0, max - 1)}…`;
}

export default function AttackPathKillChainGraph({
    killChains,
    className = '',
    isFullscreen = false
}: Props) {
    const wrapRef = useRef<HTMLDivElement>(null);
    const [width, setWidth] = useState(800);

    useEffect(() => {
        const el = wrapRef.current;
        if (!el) return;

        const ro = new ResizeObserver((entries) => {
            const w = entries[0]?.contentRect.width;
            if (w && w > 0) setWidth(Math.floor(w));
        });
        ro.observe(el);
        setWidth(Math.floor(el.clientWidth || 800));

        return () => ro.disconnect();
    }, []);

    useEffect(() => {
        const el = wrapRef.current;
        if (!el) return;

        d3.select(el).selectAll('*').remove();

        const layout = buildKillChainLayout(killChains, width);

        if (!layout || !layout.nodes.length) {
            d3.select(el)
                .append('div')
                .attr(
                    'class',
                    'flex items-center justify-center text-sm text-text-tertiary p-8 border border-dashed border-border-medium rounded-lg bg-bg-tertiary'
                )
                .text('No structured kill-chain steps were returned. Run analysis or check the LLM JSON.');
            return;
        }

        const svg = d3
            .select(el)
            .append('svg')
            .attr('width', layout.width)
            .attr('height', layout.height)
            .attr('viewBox', `0 0 ${layout.width} ${layout.height}`)
            .style('max-width', '100%')
            .style('height', 'auto')
            .style('background', BG)
            .style('border-radius', '8px');

        const defs = svg.append('defs');
        defs
            .append('marker')
            .attr('id', 'ap-arrow')
            .attr('viewBox', '0 -5 10 10')
            .attr('refX', 10)
            .attr('refY', 0)
            .attr('markerWidth', 6)
            .attr('markerHeight', 6)
            .attr('orient', 'auto')
            .append('path')
            .attr('d', 'M0,-5L10,0L0,5')
            .attr('fill', EDGE);

        const g = svg.append('g');

        // Chain titles
        g.selectAll('text.chain-title')
            .data(layout.bands)
            .join('text')
            .attr('class', 'chain-title')
            .attr('x', 20)
            .attr('y', (d) => d.titleY)
            .attr('fill', MUTED)
            .attr('font-size', 11)
            .attr('font-weight', 600)
            .attr('text-anchor', 'start')
            .text((d) => truncate(d.title, 80));

        // Links (behind nodes)
        const linkGroup = g.append('g').attr('class', 'links');

        layout.links.forEach((L) => {
            const dx = L.x2 - L.x1;
            const dy = L.y2 - L.y1;
            const len = Math.sqrt(dx * dx + dy * dy) || 1;
            const ux = dx / len;
            const uy = dy / len;
            const shrink = 28;
            const x1 = L.x1 + ux * shrink;
            const y1 = L.y1 + uy * shrink;
            const x2 = L.x2 - ux * shrink;
            const y2 = L.y2 - uy * shrink;

            linkGroup
                .append('line')
                .attr('x1', x1)
                .attr('y1', y1)
                .attr('x2', x2)
                .attr('y2', y2)
                .attr('stroke', EDGE)
                .attr('stroke-width', 2)
                .attr('marker-end', 'url(#ap-arrow)');

            const mx = (x1 + x2) / 2;
            const my = (y1 + y2) / 2 - 14;
            linkGroup
                .append('text')
                .attr('x', mx)
                .attr('y', my)
                .attr('text-anchor', 'middle')
                .attr('fill', ACCENT)
                .attr('font-size', 10)
                .text(truncate(L.label, 36));
        });

        // Nodes
        const nodeG = g
            .selectAll('g.node')
            .data(layout.nodes)
            .join('g')
            .attr('class', 'node')
            .attr('transform', (d) => `translate(${d.x},${d.y})`);

        nodeG
            .append('circle')
            .attr('r', 26)
            .attr('fill', '#1e293b')
            .attr('stroke', ACCENT)
            .attr('stroke-width', 2)
            .style('cursor', 'default');

        nodeG
            .append('text')
            .attr('text-anchor', 'middle')
            .attr('dy', 5)
            .attr('fill', TEXT)
            .attr('font-size', 10)
            .attr('font-weight', 600)
            .text((d) => truncate(d.label, 14));

        nodeG
            .append('title')
            .text((d) => d.label);

        return () => {
            d3.select(el).selectAll('*').remove();
        };
    }, [killChains, width]);

    const minH = isFullscreen ? 'min(85vh, 1200px)' : '420px';

    return (
        <div
            ref={wrapRef}
            className={`w-full overflow-auto rounded-lg border border-border-medium bg-bg-tertiary ${className}`}
            style={{ minHeight: minH }}
        />
    );
}
