// ProductionAllocator.swift
// Colony-wide proportional allocation, in two phases so the energy grid can be
// resolved without circularity:
//
//   Phase A — energy producers resolve first, exempt from the grid factor.
//             (Otherwise a brownout throttles the plant and deepens itself.)
//   Grid    — supply comes from producers' ACHIEVED throughput; demand from
//             consumers' output-capped desire.
//   Phase B — consumers resolve against the grid factor and proportional inputs.
//
// Producers therefore also get first call on shared inputs. That's deliberate:
// keeping the lights on takes precedence.
//
// Pure and portable — the seam a server-side SimulationCore plugs into.

import Foundation

struct ProductionAllocator {

    private static let tolerance = 0.001

    /// Runs a full tick. Returns the grid figures for display, including the
    /// factor actually used to resolve Phase B — this is the single source of
    /// truth for the grid factor; Colony stores it verbatim rather than
    /// recomputing it from gridSupply/gridDemand. HELIOS.md §18 S7.
    @discardableResult
    static func run(
        chains: inout [ChainDetail],
        stock: inout ColonyStock,
        economyRate: Double
    ) -> (supply: Double, demand: Double, factor: Double) {
        guard !chains.isEmpty else { return (0, 0, 1) }

        // Output headroom for every chain. Energy producers have no output
        // store, so they're never capped here.
        var outputCap = [Double](repeating: 1, count: chains.count)
        for i in chains.indices {
            guard let out = chains[i].output else { continue }
            let want = out.ratePerMin * economyRate
            guard want > 0 else { continue }
            let headroom = max(0, stock.capacity(of: out.resourceID) - stock.amount(of: out.resourceID))
            outputCap[i] = min(1, headroom / want)
        }

        let producers = chains.indices.filter { chains[$0].isEnergyProducer }
        let consumers = chains.indices.filter { !chains[$0].isEnergyProducer }

        // Phase A — producers, exempt from the grid.
        allocate(
            indices: producers,
            chains: &chains,
            stock: &stock,
            economyRate: economyRate,
            energyFactor: 1,
            outputCap: outputCap
        )

        // Grid balance.
        var supply = 0.0
        for i in producers {
            supply += chains[i].energyProduced * chains[i].throughput
        }
        var demand = 0.0
        for i in consumers {
            demand += chains[i].energyRequired * outputCap[i]
        }
        let energyFactor = demand <= 0 ? 1 : min(1, supply / demand)

        // Phase B — consumers.
        allocate(
            indices: consumers,
            chains: &chains,
            stock: &stock,
            economyRate: economyRate,
            energyFactor: energyFactor,
            outputCap: outputCap
        )

        return (supply, demand, energyFactor)
    }

    /// Proportional input allocation across one set of chains.
    private static func allocate(
        indices: [Int],
        chains: inout [ChainDetail],
        stock: inout ColonyStock,
        economyRate: Double,
        energyFactor: Double,
        outputCap: [Double]
    ) {
        guard !indices.isEmpty else { return }

        var desired: [Int: Double] = [:]
        for i in indices {
            desired[i] = min(outputCap[i], energyFactor)
        }

        // Aggregate demand, then share what exists in proportion to it.
        var demand: [Resource.ID: Double] = [:]
        for i in indices {
            for input in chains[i].inputs {
                demand[input.resourceID, default: 0] += (desired[i] ?? 1) * input.ratePerMin * economyRate
            }
        }

        var ratio: [Resource.ID: Double] = [:]
        for (id, wanted) in demand {
            ratio[id] = wanted <= 0 ? 1 : min(1, stock.amount(of: id) / wanted)
        }

        for i in indices {
            var inputFactor = 1.0
            var binding: Resource.ID?
            for input in chains[i].inputs {
                let r = ratio[input.resourceID] ?? 1
                if r < inputFactor {
                    inputFactor = r
                    binding = input.resourceID
                }
            }

            let achieved = (desired[i] ?? 1) * inputFactor

            for input in chains[i].inputs {
                stock.drain(input.resourceID, achieved * input.ratePerMin * economyRate)
            }
            if let out = chains[i].output {
                stock.deposit(out.resourceID, achieved * out.ratePerMin * economyRate)
            }

            chains[i].throughput = achieved
            chains[i].status = resolveStatus(
                inputFactor: inputFactor,
                energyFactor: energyFactor,
                outputCap: outputCap[i],
                binding: binding
            )
        }
    }

    /// Reports only the single tightest constraint, so the UI names one
    /// actionable thing.
    private static func resolveStatus(
        inputFactor: Double,
        energyFactor: Double,
        outputCap: Double,
        binding: Resource.ID?
    ) -> ChainStatus {
        let tightest = min(inputFactor, min(energyFactor, outputCap))
        if tightest >= 1 - tolerance { return .running }

        if inputFactor <= energyFactor, inputFactor <= outputCap, let binding {
            return .limited(.input(binding))
        }
        if energyFactor <= outputCap {
            return .limited(.power)
        }
        return .stalled
    }
}
