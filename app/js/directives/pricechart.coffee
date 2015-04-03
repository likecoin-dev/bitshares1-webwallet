initChart = (scope) ->

    Highcharts.setOptions
        lang:
            rangeSelectorZoom: ""
        
    new Highcharts.StockChart
        chart:
            renderTo: "pricechart"
            height: 400
            zoomType: 'x'
            pinchType: 'x'

        credits:
            enabled: false

        title:
            text: null #"Price history "

        xAxis:
            type: "datetime"
            linewidth: 0

        legend:
            enabled: false

        plotOptions:
            candlestick:
                color: "#f01717"
                upColor: "#0ab92b"
            series:
                marker:
                    enabled: false

        tooltip:
            shared: true
            backgroundColor: 'none'
            borderWidth: 0
            shadow: false
            useHTML: true
            padding: 0
            # pointFormat: " O: {point.open:.4f} H: {point.high:.4f} L: {point.low:.4f} C: {point.close:.4f}"
            formatter: () ->
                TA = ""
                if this.points.length == 5
                    TA = "<br> MACD:"+this.points[2].y.toFixed(2)+ " Signal line:"+this.points[4].y.toFixed(2)
                if (this.points[0].point and this.points[0].point.open) and (this.points[1].point and this.points[1].point.y)
                    return "O: " + this.points[0].point.open.toFixed(4) + " H: " + this.points[0].point.high.toFixed(4) + " L: " + this.points[0].point.low.toFixed(4) + " C: " + this.points[0].point.close.toFixed(4) + " V: " + this.points[1].point.y.toFixed(2)+TA
                else if this.points.length == 1 and this.points[0] and this.points[0].point.open
                    return "O: " + this.points[0].point.open.toFixed(4) + " H: " + this.points[0].point.high + " L: " + this.points[0].point.low.toFixed(4) + " C: " + this.points[0].point.close.toFixed(4)+TA
                else if this.points.length == 1 and this.points[1] and this.points[1].point.y
                    return "V: " + this.points[1].point.y.toFixed(2)+TA
                else
                    return ""
            positioner: () ->
                return { x: 300, y: 5 };
        
            
        ###
            changeDecimals: 4
            valueDecimals: (scope.volumePrecision+"").length - 1
        ###
        scrollbar:
            enabled: false

        navigator:
            enabled: false

        rangeSelector:
            enabled: true
            inputEnabled: false
            allButtonsEnabled: true
            selected: 3
            buttons: [
                type: "minute"
                count: 30
                text: "30m"
            ,
                type: "hour"
                count: 6
                text: "6h"
            ,
                type: "day"
                count: 1
                text: "1d"
            ,
                type: "day"
                count: 7
                text: "7d"
            ,
                type: "day"
                count: 14
                text: "14d"
            ,
                type: "day"
                count: 30
                text: "30d"
#            ,
#                type: "ytd"
#                text: "YTD"
#            ,
#                type: "year"
#                count: 1
#                text: "Year"
            ,
                type: "all"
                text: "All"
            ]

        yAxis: [
            title: { text: '' }
            opposite: true
            labels:
                enabled: true 
                align: 'left'
                x: 2
            height: "65%"
            gridLineColor: 'transparent'
        ,
            labels:
                enabled: false 
            title: { text: 'MACD' }
            color: "#4572A7"
            top: "65%"
            height: "20%"            
            offset: 0
            lineWidth: 1
            gridLineColor: 'transparent'
            plotLines: [
                color: '#FF0000'
                width: 1
                value: 0
            ]
        ,
            labels:
                enabled: false 
            title: { text: '' }
            color: "#4572A7"
            top: "85%"
            height: "15%"            
            gridLineColor: 'transparent'
        ]

        series: [
            id: "primary"
            type: 'candlestick'
            name: 'Price'
            data: scope.pricedata
            zIndex: 10
        ,
            type: 'column'
            name: 'Volume'
            data: scope.volumedata
            yAxis: 2
            zIndex: 9
        ,
            name: "MACD"
            linkedTo: 'primary'
            showInLegend: true
            type: 'trendline'
            algorithm: 'MACD'
            zIndex: 7
            yAxis: 1
        ,
            name : 'Signal line',
            linkedTo: 'primary',
            yAxis: 1,
            showInLegend: true,
            type: 'trendline',
            algorithm: 'signalLine'
        ,
            name: 'Histogram',
            linkedTo: 'primary',
            yAxis: 1,
            showInLegend: true,
            type: 'histogram'
            zIndex: 8
        ]

angular.module("app.directives").directive "pricechart", ->
    restrict: "E"
    replace: true
    scope:
        pricedata: "="
        volumedata: "="
        marketName: "="
        volumeSymbol: "="
        volumePrecision: "="
        priceSymbol: "="

    controller: ($scope, $element, $attrs) ->
        #console.log "pricechart controller"

    template: "<div id=\"pricechart\"></div>"

    chart: null

    link: (scope, element, attrs) ->
        chart = null

        scope.$watch "pricedata", (newValue) =>
            if newValue and not chart
                chart = initChart(scope)
            else if chart
                chart.series[0].setData newValue, true
        , true

        scope.$watch "volumedata", (newValue) =>
            return unless chart
            chart.series[1].setData newValue, true
        , true

