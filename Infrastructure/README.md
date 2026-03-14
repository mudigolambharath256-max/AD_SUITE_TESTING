# Infrastructure Checks

This folder contains checks for Active Directory infrastructure components including sites, subnets, DNS zones, and organizational units.

## Overview

These checks assess the AD topology and structure that supports replication, authentication, and organizational hierarchy.

## Checks in This Category

### Sites & Replication Topology (2 checks)
- **AD-014**: Sites Configuration - AD Sites and site links
- **AD-015**: Subnets Configuration - Subnets and site associations

### DNS Infrastructure (1 check)
- **AD-021**: DNS Zones - AD-integrated DNS zones

### Organizational Structure (1 check)
- **AD-032**: Organizational Units (OU) Inventory - All OUs in domain

## Severity Distribution

- **INFO**: 4 checks (all informational/inventory)

## Usage

Each check folder contains 5 implementation variants:
1. **powershell.ps1** - ActiveDirectory module (requires RSAT)
2. **adsi.ps1** - Native ADSI (no dependencies)
3. **csharp.cs** - Standalone C# code
4. **cmd.bat** - Windows batch with dsquery
5. **combined_multiengine.ps1** - Multi-engine orchestrator

## Quick Start

```powershell
# List all AD sites
.\AD-014_Sites_Configuration\AD-014_Sites_Configuration\powershell.ps1

# Check subnet-to-site mappings
.\AD-015_Subnets_Configuration\AD-015_Subnets_Configuration\powershell.ps1

# List DNS zones
.\AD-021_DNS_Zones\AD-021_DNS_Zones\powershell.ps1

# Inventory all OUs
.\AD-032_Organizational_Units_OU_Inventory\AD-032_Organizational_Units_OU_Inventory\powershell.ps1
```

## Sites & Subnets Overview

### AD Sites (AD-014)

**Purpose**:
- Define physical network locations
- Control replication topology
- Optimize authentication traffic
- Enable location-aware services

**Information Collected**:
- Site names
- Site links and costs
- Replication schedules
- Inter-site transport protocols

**Best Practices**:
- Create sites for each physical location
- Configure site links with accurate costs
- Optimize replication schedules for WAN links
- Use site-aware services (DFS, Exchange, etc.)

### Subnets (AD-015)

**Purpose**:
- Map IP subnets to AD sites
- Enable automatic site assignment
- Support location-based authentication

**Information Collected**:
- Subnet definitions (CIDR notation)
- Site associations
- Subnet descriptions

**Common Issues**:
- Missing subnet definitions (clients can't determine site)
- Overlapping subnets (ambiguous site assignment)
- Incorrect site associations (suboptimal DC selection)

**Best Practices**:
- Define all subnets in AD Sites and Services
- Associate each subnet with correct site
- Document subnet purposes
- Review subnet mappings during network changes

## DNS Zones (AD-021)

**Purpose**:
- Inventory AD-integrated DNS zones
- Verify DNS infrastructure
- Support troubleshooting

**Information Collected**:
- Zone names
- Zone types (Primary, Secondary, Stub)
- AD integration status
- Replication scope (Forest, Domain, Custom)

**AD-Integrated Zones Benefits**:
- Secure dynamic updates
- Multi-master replication
- Automatic zone transfer
- Integration with AD security

**Best Practices**:
- Use AD-integrated zones for internal domains
- Configure secure dynamic updates only
- Set appropriate replication scope
- Monitor zone health and replication

## Organizational Units (AD-032)

**Purpose**:
- Document OU structure
- Support GPO planning
- Enable delegation analysis

**Information Collected**:
- OU names and paths
- OU hierarchy
- Distinguished names

**OU Design Considerations**:
- Align with administrative delegation needs
- Support GPO application strategy
- Balance depth vs. complexity
- Document OU purposes

**Best Practices**:
- Keep OU structure simple and logical
- Use descriptive OU names
- Document delegation model
- Avoid excessive nesting (≤5 levels)
- Separate users, computers, and groups

## Use Cases

### Network Planning
1. Run AD-014 and AD-015 to document current topology
2. Identify missing subnets
3. Verify site link costs match network reality
4. Plan site additions for new locations

### Troubleshooting
1. Check subnet definitions (AD-015) for client site assignment issues
2. Review site links (AD-014) for replication problems
3. Verify DNS zones (AD-021) for name resolution issues
4. Analyze OU structure (AD-032) for GPO application problems

### Documentation
1. Generate infrastructure inventory
2. Create network diagrams from site/subnet data
3. Document OU hierarchy for delegation
4. Maintain DNS zone inventory

### Compliance & Auditing
1. Verify infrastructure matches documentation
2. Audit OU structure for compliance
3. Review DNS zone configurations
4. Validate site topology design

## Performance Notes

- **AD-014**: Fast (small number of sites in most environments)
- **AD-015**: Fast (typically <100 subnets)
- **AD-021**: Fast (limited number of DNS zones)
- **AD-032**: Can be slow in large environments (thousands of OUs)

## Related Categories

- **Domain_Controllers** - DC inventory and configuration
- **Domain_Configuration** - Domain-wide settings
- **Trust_Management** - Trust relationships

## Total Checks: 4
