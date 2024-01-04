module Shape exposing
    ( arc, Arc, centroid
    , PieConfig, pie, defaultPieConfig
    , line, lineRadial, area, areaRadial
    , linearCurve
    , basisCurve, basisCurveClosed, basisCurveOpen
    , bumpXCurve, bumpYCurve
    , bundleCurve
    , cardinalCurve, cardinalCurveClosed, cardinalCurveOpen
    , catmullRomCurve, catmullRomCurveClosed, catmullRomCurveOpen
    , monotoneInXCurve, monotoneInYCurve
    , stepCurve, naturalCurve
    , StackConfig, StackResult, stack
    , stackOffsetNone, stackOffsetDiverging, stackOffsetExpand, stackOffsetSilhouette, stackOffsetWiggle
    , sortByInsideOut
    )

{-| Visualizations typically consist of discrete graphical marks, such as symbols,
arcs, lines and areas. While the rectangles of a bar chart may be easy enough to
generate directly using SVG or Canvas, other shapes are complex, such as rounded
annular sectors and centripetal Catmull–Rom splines. This module provides a
variety of shape generators for your convenience.


# Arcs

[![Pie Chart](https://elm-visualization.netlify.com/PieChart/preview.png)](https://elm-visualization.netlify.com/PieChart/)

@docs arc, Arc, centroid


# Pies

@docs PieConfig, pie, defaultPieConfig


# Lines

[![Line Chart](https://elm-visualization.netlify.com/LineChart/preview.png)](https://elm-visualization.netlify.com/LineChart/)

@docs line, lineRadial, area, areaRadial


# Curves

While lines are defined as a sequence of two-dimensional [x, y] points, and areas are similarly
defined by a topline and a baseline, there remains the task of transforming this discrete representation
into a continuous shape: i.e., how to interpolate between the points. A variety of curves are provided for this purpose.

@docs linearCurve
@docs basisCurve, basisCurveClosed, basisCurveOpen
@docs bumpXCurve, bumpYCurve
@docs bundleCurve
@docs cardinalCurve, cardinalCurveClosed, cardinalCurveOpen
@docs catmullRomCurve, catmullRomCurveClosed, catmullRomCurveOpen
@docs monotoneInXCurve, monotoneInYCurve
@docs stepCurve, naturalCurve


# Stack

A stack is a way to fit multiple graphs into one drawing. Rather than drawing graphs on top of each other,
the layers are stacked. This is useful when the relation between the graphs is of interest.

In most cases, the absolute size of a piece of data becomes harder to determine for the reader.

@docs StackConfig, StackResult, stack


## Stack Offset

The method of stacking.

@docs stackOffsetNone, stackOffsetDiverging, stackOffsetExpand, stackOffsetSilhouette, stackOffsetWiggle


## Stack Order

The order of the layers. Normal list functions can be used, for instance

    -- keep order of the input data
    identity

    -- reverse
    List.reverse

    -- decreasing by sum of the values (largest is lowest)
    List.sortBy (Tuple.second >> List.sum >> negate)

@docs sortByInsideOut

-}

import Curve
import Path exposing (Path)
import Shape.Bump as Bump
import Shape.Generators
import Shape.Pie
import Shape.Stack
import SubPath exposing (SubPath)


{-| Used to configure an `arc`. These can be generated by a `pie`, but you can
easily modify these later.


### innerRadius : Float

Usefull for creating a donut chart. A negative value is treated as zero. If larger
than `outerRadius` they are swapped.


### outerRadius : Float

The radius of the arc. A negative value is treated as zero. If smaller
than `innerRadius` they are swapped.


### cornerRadius : Float

If the corner radius is greater than zero, the corners of the arc are rounded
using circles of the given radius. For a circular sector, the two outer corners
are rounded; for an annular sector, all four corners are rounded. The corner
circles are shown in this diagram:

[![Corner Radius](https://elm-visualization.netlify.com/CornerRadius/preview.png)](https://elm-visualization.netlify.com/CornerRadius/)

The corner radius may not be larger than `(outerRadius - innerRadius) / 2`.
In addition, for arcs whose angular span is less than π, the corner radius may
be reduced as two adjacent rounded corners intersect. This is occurs more often
with the inner corners.


### startAngle : Float

The angle is specified in radians, with 0 at -y (12 o’clock) and positive angles
proceeding clockwise. If |endAngle - startAngle| ≥ τ, a complete circle or
annulus is generated rather than a sector.


### endAngle : Float

The angle is specified in radians, with 0 at -y (12 o’clock) and positive angles
proceeding clockwise. If |endAngle - startAngle| ≥ τ, a complete circle or annulus
is generated rather than a sector.


### padAngle : Float

The pad angle is converted to a fixed linear distance separating adjacent arcs,
defined as padRadius \* padAngle. This distance is subtracted equally from the
start and end of the arc. If the arc forms a complete circle or annulus,
as when |endAngle - startAngle| ≥ τ, the pad angle is ignored.

If the inner radius or angular span is small relative to the pad angle, it may
not be possible to maintain parallel edges between adjacent arcs. In this case,
the inner edge of the arc may collapse to a point, similar to a circular sector.
For this reason, padding is typically only applied to annular sectors
(i.e., when innerRadius is positive), as shown in this diagram:

[![Pad Angle](https://elm-visualization.netlify.com/PadAngle/preview.png)](https://elm-visualization.netlify.com/PadAngle/)

The recommended minimum inner radius when using padding is outerRadius \* padAngle / sin(θ),
where θ is the angular span of the smallest arc before padding. For example,
if the outer radius is 200 pixels and the pad angle is 0.02 radians,
a reasonable θ is 0.04 radians, and a reasonable inner radius is 100 pixels.

Often, the pad angle is not set directly on the arc generator, but is instead
computed by the pie generator so as to ensure that the area of padded arcs is
proportional to their value.
If you apply a constant pad angle to the arc generator directly, it tends to
subtract disproportionately from smaller arcs, introducing distortion.


### padRadius : Float

The pad radius determines the fixed linear distance separating adjacent arcs,
defined as padRadius \* padAngle.

-}
type alias Arc =
    { innerRadius : Float
    , outerRadius : Float
    , cornerRadius : Float
    , startAngle : Float
    , endAngle : Float
    , padAngle : Float
    , padRadius : Float
    }


{-| The arc generator produces a [circular](https://en.wikipedia.org/wiki/Circular_sector)
or [annular](https://en.wikipedia.org/wiki/Annulus_%28mathematics%29) sector, as in
a pie or donut chart. If the difference between the start and end angles (the
angular span) is greater than [τ](https://en.wikipedia.org/wiki/Turn_%28geometry%29#Tau_proposals),
the arc generator will produce a complete circle or annulus. If it is less than
[τ](https://en.wikipedia.org/wiki/Turn_%28geometry%29#Tau_proposal), arcs may have
rounded corners and angular padding. Arcs are always centered at ⟨0,0⟩; use a
transform to move the arc to a different position.

See also the pie generator, which computes the necessary angles to represent an
array of data as a pie or donut chart; these angles can then be passed to an arc
generator.

-}
arc : Arc -> Path
arc =
    Shape.Pie.arc


{-| Computes the midpoint (x, y) of the center line of the arc that would be
generated by the given arguments. The midpoint is defined as
(startAngle + endAngle) / 2 and (innerRadius + outerRadius) / 2. For example:

[![Centroid](https://elm-visualization.netlify.com/Centroid/preview.png)](https://elm-visualization.netlify.com/Centroid/)

Note that this is not the geometric center of the arc, which may be outside the arc;
this function is merely a convenience for positioning labels.

-}
centroid : Arc -> ( Float, Float )
centroid =
    Shape.Pie.centroid


{-| Used to configure a `pie` generator function.

`innerRadius`, `outerRadius`, `cornerRadius` and `padRadius` are simply forwarded
to the `Arc` result. They are provided here simply for convenience.


### valueFn : a -> Float

This is used to compute the actual numerical value used for computing the angles.
You may use a `List.map` to preprocess data into numbers instead, but this is
useful if trying to use `sortingFn`.


### sortingFn : a -> a -> Order

Sorts the data. Sorting does not affect the order of the generated arc list,
which is always in the same order as the input data list; it merely affects
the computed angles of each arc. The first arc starts at the start angle and the
last arc ends at the end angle.


### startAngle : Float

The start angle here means the overall start angle of the pie, i.e., the start
angle of the first arc. The units of angle are arbitrary, but if you plan to use
the pie generator in conjunction with an arc generator, you should specify an
angle in radians, with 0 at -y (12 o’clock) and positive angles proceeding clockwise.


### endAngle : Float

The end angle here means the overall end angle of the pie, i.e., the end angle
of the last arc. The units of angle are arbitrary, but if you plan to use the
pie generator in conjunction with an arc generator, you should specify an angle
in radians, with 0 at -y (12 o’clock) and positive angles proceeding clockwise.

The value of the end angle is constrained to startAngle ± τ, such that |endAngle - startAngle| ≤ τ.


### padAngle : Float

The pad angle here means the angular separation between each adjacent arc. The
total amount of padding reserved is the specified angle times the number of
elements in the input data list, and at most |endAngle - startAngle|; the
remaining space is then divided proportionally by value such that the relative
area of each arc is preserved.

-}
type alias PieConfig a =
    { startAngle : Float
    , endAngle : Float
    , padAngle : Float
    , sortingFn : a -> a -> Order
    , valueFn : a -> Float
    , innerRadius : Float
    , outerRadius : Float
    , cornerRadius : Float
    , padRadius : Float
    }


{-| The default config for generating pies.

    import Shape exposing (defaultPieConfig)

    pieData =
        Shape.pie { defaultPieConfig | outerRadius = 230 } model

Note that if you change `valueFn`, you will likely also want to change `sortingFn`.

-}
defaultPieConfig : PieConfig Float
defaultPieConfig =
    { startAngle = 0
    , endAngle = 2 * pi
    , padAngle = 0
    , sortingFn = Basics.compare
    , valueFn = identity
    , innerRadius = 0
    , outerRadius = 100
    , cornerRadius = 0
    , padRadius = 0
    }


{-| The pie generator does not produce a shape directly, but instead computes
the necessary angles to represent a tabular dataset as a pie or donut chart;
these angles can then be passed to an `arc` generator.
-}
pie : PieConfig a -> List a -> List Arc
pie =
    Shape.Pie.pie


{-| Produces a polyline through the specified points.

[![linear curve illustration](https://elm-visualization.netlify.com/Curves/linear@2x.png)](https://elm-visualization.netlify.com/Curves/#linear)

-}
linearCurve : List ( Float, Float ) -> SubPath
linearCurve =
    Curve.linear


{-| Produces a cubic [basis spline](https://en.wikipedia.org/wiki/B-spline) using the specified control points.
The first and last points are triplicated such that the spline starts at the first point and ends at the last
point, and is tangent to the line between the first and second points, and to the line between the penultimate
and last points.

[![basis curve illustration](https://elm-visualization.netlify.com/Curves/basis@2x.png)](https://elm-visualization.netlify.com/Curves/#basis)

-}
basisCurve : List ( Float, Float ) -> SubPath
basisCurve =
    Curve.basis


{-| Produces a closed cubic basis spline using the specified control points. When a line segment ends, the first three control points are repeated, producing a closed loop with C2 continuity.

[![closed basis curve illustration](https://elm-visualization.netlify.com/Curves/basisclosed@2x.png)](https://elm-visualization.netlify.com/Curves/#basisclosed)

-}
basisCurveClosed : List ( Float, Float ) -> SubPath
basisCurveClosed =
    Curve.basisClosed


{-| Produces a cubic basis spline using the specified control points. Unlike basis, the first and last points are not repeated, and thus the curve typically does not intersect these points.

[![open basis curve illustration](https://elm-visualization.netlify.com/Curves/basisopen@2x.png)](https://elm-visualization.netlify.com/Curves/#basisopen)

-}
basisCurveOpen : List ( Float, Float ) -> SubPath
basisCurveOpen =
    Curve.basisOpen


{-| Produces a straightened cubic [basis spline](https://en.wikipedia.org/wiki/B-spline) using the specified control points,
with the spline straightened according to the curve’s beta (a reasonable default is `0.85`). This curve is typically
used in hierarchical edge bundling to disambiguate connections, as proposed by Danny Holten
in [Hierarchical Edge Bundles: Visualization of Adjacency Relations in Hierarchical Data](https://www.researchgate.net/profile/Danny_Holten/publication/6715561_Hierarchical_Edge_Bundles_Visualization_of_Adjacency_Relations_in_Hierarchical_Data/links/0deec535a57c5dc79d000000/Hierarchical-Edge-Bundles-Visualization-of-Adjacency-Relations-in-Hierarchical-Data.pdf?origin=publication_detail).

This curve is not suitable to be used with areas.

[![bundle curve illustration](https://elm-visualization.netlify.com/Curves/bundle@2x.png)](https://elm-visualization.netlify.com/Curves/#bundle)

-}
bundleCurve : Float -> List ( Float, Float ) -> SubPath
bundleCurve beta =
    Curve.bundle (clamp 0 1 beta)


{-| Produces a cubic [cardinal spline](https://en.wikipedia.org/wiki/Cubic_Hermite_spline#Cardinal_spline) using
the specified control points, with one-sided differences used for the first and last piece.

The tension parameter determines the length of the tangents: a tension of one yields all zero tangents, equivalent to
`linearCurve`; a tension of zero produces a uniform Catmull–Rom spline.

[![cardinal curve illustration](https://elm-visualization.netlify.com/Curves/cardinal@2x.png)](https://elm-visualization.netlify.com/Curves/#cardinal)

-}
cardinalCurve : Float -> List ( Float, Float ) -> SubPath
cardinalCurve tension =
    Curve.cardinal (clamp 0 1 tension)


{-| Produces a cubic [cardinal spline](https://en.wikipedia.org/wiki/Cubic_Hermite_spline#Cardinal_spline) using
the specified control points. At the end, the first three control points are repeated, producing a closed loop.

The tension parameter determines the length of the tangents: a tension of one yields all zero tangents, equivalent to
`linearCurve`; a tension of zero produces a uniform Catmull–Rom spline.

[![cardinal closed curve illustration](https://elm-visualization.netlify.com/Curves/cardinalclosed@2x.png)](https://elm-visualization.netlify.com/Curves/#cardinalclosed)

-}
cardinalCurveClosed : Float -> List ( Float, Float ) -> SubPath
cardinalCurveClosed tension =
    Curve.cardinalClosed (clamp 0 1 tension)


{-| Produces a cubic [cardinal spline](https://en.wikipedia.org/wiki/Cubic_Hermite_spline#Cardinal_spline) using
the specified control points. Unlike curveCardinal, one-sided differences are not used for the first and last piece, and thus the curve starts at the second point and ends at the penultimate point.

The tension parameter determines the length of the tangents: a tension of one yields all zero tangents, equivalent to
`linearCurve`; a tension of zero produces a uniform Catmull–Rom spline.

[![cardinal open curve illustration](https://elm-visualization.netlify.com/Curves/cardinalopen@2x.png)](https://elm-visualization.netlify.com/Curves/#cardinalopen)

-}
cardinalCurveOpen : Float -> List ( Float, Float ) -> SubPath
cardinalCurveOpen tension =
    Curve.cardinalOpen (clamp 0 1 tension)


{-| Produces a cubic Catmull–Rom spline using the specified control points and the parameter alpha (a good default is 0.5),
as proposed by Yuksel et al. in [On the Parameterization of Catmull–Rom Curves](http://www.cemyuksel.com/research/catmullrom_param/),
with one-sided differences used for the first and last piece.

If alpha is zero, produces a uniform spline, equivalent to `curveCardinal` with a tension of zero; if alpha is one,
produces a chordal spline; if alpha is 0.5, produces a [centripetal spline](https://en.wikipedia.org/wiki/Centripetal_Catmull–Rom_spline).
Centripetal splines are recommended to avoid self-intersections and overshoot.

[![Catmul-Rom curve illustration](https://elm-visualization.netlify.com/Curves/catmullrom@2x.png)](https://elm-visualization.netlify.com/Curves/#catmullrom)

-}
catmullRomCurve : Float -> List ( Float, Float ) -> SubPath
catmullRomCurve alpha =
    Curve.catmullRom (clamp 0 1 alpha)


{-| Produces a cubic Catmull–Rom spline using the specified control points and the parameter alpha (a good default is 0.5),
as proposed by Yuksel et al. When a line segment ends, the first three control points are repeated, producing a closed loop.

If alpha is zero, produces a uniform spline, equivalent to `curveCardinal` with a tension of zero; if alpha is one,
produces a chordal spline; if alpha is 0.5, produces a [centripetal spline](https://en.wikipedia.org/wiki/Centripetal_Catmull–Rom_spline).
Centripetal splines are recommended to avoid self-intersections and overshoot.

[![Catmul-Rom closed curve illustration](https://elm-visualization.netlify.com/Curves/catmullromclosed@2x.png)](https://elm-visualization.netlify.com/Curves/#catmullromclosed)

-}
catmullRomCurveClosed : Float -> List ( Float, Float ) -> SubPath
catmullRomCurveClosed alpha =
    Curve.catmullRomClosed (clamp 0 1 alpha)


{-| Produces a cubic Catmull–Rom spline using the specified control points and the parameter alpha (a good default is 0.5),
as proposed by Yuksel et al. Unlike curveCatmullRom, one-sided differences are not used for the first and last piece, and thus the curve starts at the second point and ends at the penultimate point.

If alpha is zero, produces a uniform spline, equivalent to `curveCardinal` with a tension of zero; if alpha is one,
produces a chordal spline; if alpha is 0.5, produces a [centripetal spline](https://en.wikipedia.org/wiki/Centripetal_Catmull–Rom_spline).
Centripetal splines are recommended to avoid self-intersections and overshoot.

[![Catmul-Rom open curve illustration](https://elm-visualization.netlify.com/Curves/catmullromopen@2x.png)](https://elm-visualization.netlify.com/Curves/#catmullromopen)

-}
catmullRomCurveOpen : Float -> List ( Float, Float ) -> SubPath
catmullRomCurveOpen alpha =
    Curve.catmullRomOpen (clamp 0 1 alpha)


{-| Produces a cubic spline that [preserves monotonicity](https://en.wikipedia.org/wiki/Monotonic_function)
in y, assuming monotonicity in x, as proposed by Steffen in
[A simple method for monotonic interpolation in one dimension](http://adsabs.harvard.edu/full/1990A%26A...239..443S):
“a smooth curve with continuous first-order derivatives that passes through any
given set of data points without spurious oscillations. Local extrema can occur
only at grid points where they are given by the data, but not in between two adjacent grid points.”

[![monotone in x curve illustration](https://elm-visualization.netlify.com/Curves/monotoneinx@2x.png)](https://elm-visualization.netlify.com/Curves/#monotoneinx)

-}
monotoneInXCurve : List ( Float, Float ) -> SubPath
monotoneInXCurve =
    Curve.monotoneX


{-| Produces a cubic spline that [preserves monotonicity](https://en.wikipedia.org/wiki/Monotonic_function)
in y, assuming monotonicity in y, as proposed by Steffen in
[A simple method for monotonic interpolation in one dimension](http://adsabs.harvard.edu/full/1990A%26A...239..443S):
“a smooth curve with continuous first-order derivatives that passes through any
given set of data points without spurious oscillations. Local extrema can occur
only at grid points where they are given by the data, but not in between two adjacent grid points.”
-}
monotoneInYCurve : List ( Float, Float ) -> SubPath
monotoneInYCurve =
    Curve.monotoneY


{-| Produces a [natural](https://en.wikipedia.org/wiki/Spline_interpolation) [cubic spline](http://mathworld.wolfram.com/CubicSpline.html)
with the second derivative of the spline set to zero at the endpoints.

[![natural curve illustration](https://elm-visualization.netlify.com/Curves/natural@2x.png)](https://elm-visualization.netlify.com/Curves/#natural)

-}
naturalCurve : List ( Float, Float ) -> SubPath
naturalCurve =
    Curve.natural


{-| Produces a Bézier curve between each pair of points, with horizontal tangents at each point.

[![bumpX curve illustration](https://elm-visualization.netlify.com/Curves/bumpx@2x.png)](https://elm-visualization.netlify.com/Curves/#bumpx)

-}
bumpXCurve : List ( Float, Float ) -> SubPath
bumpXCurve =
    Bump.bumpXCurve


{-| Produces a Bézier curve between each pair of points, with vertical tangents at each point.

[![bumpX curve illustration](https://elm-visualization.netlify.com/Curves/bumpy@2x.png)](https://elm-visualization.netlify.com/Curves/#bumpy)

-}
bumpYCurve : List ( Float, Float ) -> SubPath
bumpYCurve =
    Bump.bumpYCurve


{-| Produces a piecewise constant function (a step function) consisting of alternating horizontal and vertical lines.

The factor parameter changes when the y-value changes between each pair of adjacent x-values.

[![step curve illustration](https://elm-visualization.netlify.com/Curves/step@2x.png)](https://elm-visualization.netlify.com/Curves/#step)

-}
stepCurve : Float -> List ( Float, Float ) -> SubPath
stepCurve factor =
    Curve.step (clamp 0 1 factor)


{-| Generates a line for the given array of points which can be passed to the `d`
attribute of the `path` SVG element. It needs to be suplied with a curve function.
Points accepted are `Maybe`s, Nothing represent gaps in the data and corresponding
gaps will be rendered in the line.

**Note:** A single point (surrounded by Nothing) may not be visible.

Usually you will need to convert your data into a format supported by this function.
For example, if your data is a `List (Date, Float)`, you might use something like:

    lineGenerator : ( Date, Float ) -> Maybe ( Float, Float )
    lineGenerator ( x, y ) =
        Just ( Scale.convert xScale x, Scale.convert yScale y )

    linePath : List ( Date, Float ) -> Path
    linePath data =
        List.map lineGenerator data
            |> Shape.line Shape.linearCurve

where `xScale` and `yScale` would be appropriate `Scale`s.

-}
line : (List ( Float, Float ) -> SubPath) -> List (Maybe ( Float, Float )) -> Path
line =
    Shape.Generators.line


{-| This works exactly like `line`, except it interprets the points it recieves as `(angle, radius)`
pairs, where radius is in _radians_. Therefore it renders a radial layout with a center at `(0, 0)`.

Use a transform to position the layout in final rendering.

-}
lineRadial : (List ( Float, Float ) -> SubPath) -> List (Maybe ( Float, Float )) -> Path
lineRadial curve =
    Shape.Generators.line (Curve.toPolarWithCenter ( 0, 0 ) >> curve)


{-| The area generator produces an area, as in an area chart. An area is defined
by two bounding lines, either splines or polylines. Typically, the two lines
share the same x-values (x0 = x1), differing only in y-value (y0 and y1);
most commonly, y0 is defined as a constant representing zero. The first line
(the topline) is defined by x1 and y1 and is rendered first; the second line
(the baseline) is defined by x0 and y0 and is rendered second, with the points
in reverse order. With a `linearCurve` curve, this produces a clockwise polygon.

The data attribute you pass in should be a `[Just ((x0, y0), (x1, y1))]`. Passing
in `Nothing` represents gaps in the data and corresponding gaps in the area will
be rendered.

Usually you will need to convert your data into a format supported by this function.
For example, if your data is a `List (Date, Float)`, you might use something like:

    areaGenerator : ( Date, Float ) -> Maybe ( ( Float, Float ), ( Float, Float ) )
    areaGenerator ( x, y ) =
        Just
            ( ( Scale.convert xScale x, Tuple.first (Scale.rangeExtent yScale) )
            , ( Scale.convert xScale x, Scale.convert yScale y )
            )

    areaPath : List ( Date, Float ) -> Path
    areaPath data =
        List.map areaGenerator data
            |> Shape.area Shape.linearCurve

where `xScale` and `yScale` would be appropriate `Scale`s.

-}
area : (List ( Float, Float ) -> SubPath) -> List (Maybe ( ( Float, Float ), ( Float, Float ) )) -> Path
area =
    Shape.Generators.area


{-| This works exactly like `area`, except it interprets the points it recieves as `(angle, radius)`
pairs, where radius is in _radians_. Therefore it renders a radial layout with a center at `(0, 0)`.

Use a transform to position the layout in final rendering.

-}
areaRadial : (List ( Float, Float ) -> SubPath) -> List (Maybe ( ( Float, Float ), ( Float, Float ) )) -> Path
areaRadial curve =
    Shape.Generators.area (Curve.toPolarWithCenter ( 0, 0 ) >> curve)



--- STACK


{-| Configuration for a stacked chart.

  - `data`: List of values with an accompanying label.
  - `offset`: How to stack the layers on top of each other.
  - `order`: sorting function to determine the order of the layers.

Some example configs:

    stackedBarChart : StackConfig String
    stackedBarChart =
        { data = myData
        , offset = Shape.stackOffsetNone
        , order =
            -- stylistic choice: largest (by sum of values)
            -- category at the bottom
            List.sortBy (Tuple.second >> List.sum >> negate)
        }

    streamgraph : StackConfig String
    streamgraph =
        { data = myData
        , offset = Shape.stackOffsetWiggle
        , order = Shape.sortByInsideOut (Tuple.second >> List.sum)
        }

-}
type alias StackConfig a =
    { data : List ( a, List Float )
    , offset : List (List ( Float, Float )) -> List (List ( Float, Float ))
    , order : List ( a, List Float ) -> List ( a, List Float )
    }


{-| The basis for constructing a stacked chart

  - `values`: Sorted list of values, where every item is a `(yLow, yHigh)` pair.
  - `labels`: Sorted list of labels
  - `extent`: The minimum and maximum y-value. Convenient for creating scales.

-}
type alias StackResult a =
    { values : List (List ( Float, Float ))
    , labels : List a
    , extent : ( Float, Float )
    }


{-| Create a stack result
-}
stack : StackConfig a -> StackResult a
stack =
    Shape.Stack.computeStack


{-| ![Stack offset none](https://code.gampleman.eu/elm-visualization/misc/stackOffsetNone.svg)

Stacks the values on top of each other, starting at 0.

    stackOffsetNone [ [ (0, 42) ], [ (0, 70) ] ]
                --> [ [ (0, 42) ], [ (42, 112 ) ] ]

    stackOffsetNone [ [ (0, 42) ], [ (20, 70) ] ]
                --> [ [ (0, 42) ], [ (42, 112 ) ] ]

-}
stackOffsetNone : List (List ( Float, Float )) -> List (List ( Float, Float ))
stackOffsetNone =
    Shape.Stack.offsetNone


{-| ![Stack offset diverging](https://code.gampleman.eu/elm-visualization/misc/stackOffsetDiverging.svg)

Positive values are stacked above zero, negative values below zero.

    stackOffsetDiverging [ [ (0, 42) ], [ (0, -24) ] ]
                --> [ [ (0, 42) ], [ (-24, 0 ) ] ]

    stackOffsetDiverging [ [ (0, 42), (0, -20) ], [ (0, -24), (0, -24) ] ]
                --> [[(0,42),(-20,0)],[(-24,0),(-44,-20)]]

-}
stackOffsetDiverging : List (List ( Float, Float )) -> List (List ( Float, Float ))
stackOffsetDiverging =
    Shape.Stack.offsetDiverging


{-| ![stackOffsetExpand](https://code.gampleman.eu/elm-visualization/misc/stackOffsetExpand.svg)

Applies a zero baseline and normalizes the values for each point such that the topline is always one.

    stackOffsetExpand [ [ (0, 50) ], [ (50, 100) ] ]
                --> [[(0,0.5)],[(0.5,1)]]

-}
stackOffsetExpand : List (List ( Float, Float )) -> List (List ( Float, Float ))
stackOffsetExpand =
    Shape.Stack.offsetExpand


{-| ![stackOffsetSilhouette](https://code.gampleman.eu/elm-visualization/misc/stackOffsetSilhouette.svg)

Shifts the baseline down such that the center of the streamgraph is always at zero.

    stackOffsetSilhouette [ [ (0, 50) ], [ (50, 100) ] ]
                --> [[(-75,-25)],[(-25,75)]]

-}
stackOffsetSilhouette : List (List ( Float, Float )) -> List (List ( Float, Float ))
stackOffsetSilhouette =
    Shape.Stack.offsetSilhouette


{-| ![stackOffsetWiggle](https://code.gampleman.eu/elm-visualization/misc/stackOffsetWiggle.svg)

Shifts the baseline so as to minimize the weighted wiggle of layers.

Visually, high wiggle means peaks going in both directions very close to each other. The silhouette stack offset above often suffers
from having high wiggle.

    stackOffsetWiggle [ [ (0, 50) ], [ (50, 100) ] ]
                --> [[(0,50)],[(50,150)]]

-}
stackOffsetWiggle : List (List ( Float, Float )) -> List (List ( Float, Float ))
stackOffsetWiggle =
    Shape.Stack.offsetWiggle


{-| Sort such that small values are at the outer edges, and large values in the middle.

This is the recommended order for stream graphs.

-}
sortByInsideOut : (a -> Float) -> List a -> List a
sortByInsideOut =
    Shape.Stack.sortByInsideOut
