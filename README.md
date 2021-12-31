# Visualisations for the Scottish Tax and Benefit Model

This is where interactive visualisations of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl) will live.

This is a separate repository so as to keep all the messy web stuff away from the model itself.

I don't plan on there being a full blown web user interface for all the model's hundreds of parameters. Interfaces like that are very boring to write (I've [done a few](https://virtual-worlds.biz/).. ), and no-one actually uses them - for detailed work a reproducable environment like [Dr. Watson](https://juliadynamics.github.io/DrWatson.jl/dev/) is likely a better bet. Instead, I'm going to make a series of small, single screen, interfaces in [Pluto](https://plutojl.org/) and [Dash](https://dash-julia.plotly.com/) on particular topics.

The code here provides three initial views of Scotben:

* A simple [Scottish Budget Simulator](https://stb.virtual-worlds.scot/scotbudg/) - you, too, can be Kate Forbes;
* [Exploring Basic Incomes](https://ubi.virtual-worlds.scot/) - designing a workable UBI is harder than you might think;
* [Budget Constraints](https://stb.virtual-worlds.scot/bcd/) - the often weird relationship between how much you earn and how much you end up with.

![BC Demo](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/docs/bc1.gif)


![BC Demo](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/docs/bc1.gif)

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://grahamstark.github.io/Visualisations.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://grahamstark.github.io/Visualisations.jl/dev)
