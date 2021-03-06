# Nerdmobile processing app
# Ben Fasoli 

library(dygraphs)
library(leaflet)
library(xts)

source('src.R')    # for reader, proc, calibrate functions
options(shiny.maxRequestSize=200*1024^2)

# Map and Timeseries Production -----------------------------------------------
make_figs <- function(geo) {
  require(htmlwidgets)
  require(ivis)
  require(leaflet)
  tracers <- grep('Time_common|lat|lon', names(geo), value=T, invert=T)
  lapply(tracers, geo, FUN = function(tracer, geo){
    
    xt <- na.omit(geo[c(tracer, 'Time_common')])
    xt <- xts(xt[tracer], xt$Time_common)
    if (nrow(xt) < 2) return()
    colnames(xt) <- tracer
    ts <- dygraph(xt, xlab='Time (Local)', ylab=tracer) %>%
      dySeries(color='#222D33') %>%
      dyOptions(drawGrid=F, fillGraph=T, fillAlpha=0.3, strokeWidth=0.5) %>%
      dyRangeSelector(height=30, strokeColor='')
    saveWidget(ts, file=paste0(getwd(), '/UATAQ_Nerdmobile/plots/', tracer, '_map.html'),
               libdir=paste0(getwd(), '/UATAQ_Nerdmobile/plots/dependencies/'), selfcontained=F)

    geo_map <- geo[c('Time_common', 'lat', 'lon', tracer)]
    geo_map <- na.omit(geo_map)

    lati_grid <- seq(-90, 90, by = 0.0005)
    long_grid <- seq(-180, 180, by = 0.0005)

    geo_map <- geo_map %>%
      arrange(Time_common) %>%
      mutate(lati_idx = find_neighbor(lat, lati_grid),
             long_idx = find_neighbor(lon, long_grid)) %>%
      group_by(lati_idx, long_idx) %>%
      summarize_all(funs(mean(., na.rm = T))) %>%
      ungroup() %>%
      select(-lati_idx, -long_idx)

    minmax <- c(min(geo_map[tracer]), max(geo_map[tracer]))

    cols <- geo_map[[tracer]]
    cols[cols < minmax[1]] <- minmax[1]
    cols[cols > minmax[2]] <- minmax[2]
    cpal <- colorNumeric(c('blue', 'cyan', 'green', 'yellow', 'orange', 'red'),
                         seq(minmax[1], minmax[2], length.out=64))
    pop <- paste(sep='<br>',
                 paste(tracer, ':<b>', round(geo_map[[tracer]], 2), '</b>'),
                 paste('Time:  ', format(geo_map$Time_common, tz='America/Denver', '%Y-%m-%d %H:%M %Z')))
    l <- leaflet() %>%
      addTiles(urlTemplate='http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png') %>%
      fitBounds(lng1=max(geo_map$lon)+0.01, lat1=min(geo_map$lat)-0.01,
                lng2=min(geo_map$lon)-0.01, lat2=max(geo_map$lat)+0.01) %>%
      addCircles(lng=geo_map$lon, lat=geo_map$lat, radius=30, popup=pop, stroke=T, weight=2,
                 fillColor=cpal(cols), color=cpal(cols),
                 opacity=0.3, fillOpacity=0.3) %>%
      leaflet::addLegend('bottomright', pal=cpal, values=cols, opacity=0.7)
    saveWidget(l, file=paste0(getwd(), '/UATAQ_Nerdmobile/maps/', tracer, '_map.html'),
               libdir=paste0(getwd(), '/UATAQ_Nerdmobile/maps/dependencies/'), selfcontained=F)
    return(l)
  })
}

# Server ----------------------------------------------------------------------
function(input, output, session) {
  # Dynamic UI ----------------------------------------------------------------
  output$process_ui <- renderUI({
    if(is.null(getGeoData())){
      tagList(
        fluidRow(
          column(12,
                 box(width=NULL, solidHeader=T,
                     title='Nerdmobile Processing',
                     status='danger', 
                     HTML('<center>'), img(src = 'nerdmobile1b.png', height=250),
                     img(src = 'nerdmobile4.png', height=250), HTML('</center>'),
                     hr(),
                     h5('This web framework for qualitative spatial analysis was developed for the',
                        'Nerdmobile at the University of Utah. To process a new transect, upload ',
                        'an unmodified zipped data packet. Otherwise, view a previous transect below.'),
                     fileInput('file', label=NULL, multiple=F, accept='application/zip'),
                     hr(),
                     selectInput('old_transect', h5('Previous transects'),
                                 choices=c('', rev(dir('zip_archive')))),
                     actionButton('get_old', 'Process past data', class='')
                 ),
                 h5('Developed by Ben Fasoli at the University of Utah.')
          )
        )
      )
    } else{
      tagList(
        fluidRow(
          column(12,
                 tabBox(width=NULL, side='left', id='view_tracer', title='Nerdmobile Data',
                        tabPanel('CO2', value='CO2d_ppm',
                                 leafletOutput('map_co2', height=500, width='100%'),
                                 hr(),
                                 dygraphOutput('ts_co2')),
                        tabPanel('CH4', value='CH4d_ppm',
                                 leafletOutput('map_ch4', height=500, width='100%'),
                                 hr(),
                                 dygraphOutput('ts_ch4')),
                        tabPanel('CO', value='CO_ppm',
                                 leafletOutput('map_co', height=500, width='100%'),
                                 hr(),
                                 dygraphOutput('ts_co')),
                        tabPanel('O3', value='O3_ppbv',
                                 leafletOutput('map_o3', height=500, width='100%'),
                                 hr(),
                                 dygraphOutput('ts_o3')),
                        tabPanel('NOx', value='NOx',
                                 leafletOutput('map_nox', height=500, width='100%'),
                                 hr(),
                                 dygraphOutput('ts_nox')),
                        tabPanel('PM2.5', value='pm25',
                                 leafletOutput('map_pm25', height=500, width='100%'),
                                 hr(),
                                 dygraphOutput('ts_pm25'))
                 ),
                 
                 box(width=NULL, solidHeader=T, title='Get Data!', status='danger',
                     h5('Get the geolocated data, maps, and figures.'),
                     downloadButton('datapull')
                 ),
                 h5('Developed by Ben Fasoli at the University of Utah.')
          )
        )
      )
    }
  })
  
  # Geolocate Zip Data --------------------------------------------------------
  getGeoData <- reactive({
    if (!is.null(input$get_old) && input$get_old > 0) {
      infile <- input$old_transect
    } else {
      if (is.null(input$file)) return(NULL)
      infile <- input$file$name
      file.copy(input$file$datapath, paste0('zip_archive/', infile))
    }
    geo <- proc(paste0('zip_archive/', infile), reader, calibrate)
    return(geo)
  })
  
  # Geolocate Zip Data --------------------------------------------------------
  output$map_co2 <- output$map_ch4 <- output$map_co <-
    output$map_o3 <- output$map_nox <- output$map_pm25 <- renderLeaflet({
      tracer <- input$view_tracer
      geo <- getGeoData()
      validate(need(nrow(geo) > 0, 'No geo data found. Is there a problem with the zip file?'))
      validate(need(tracer %in% names(geo), paste('No', tracer, 'data found.')))
      validate(need('lat' %in% names(geo), paste('No GPS data found.')))
      
      geo_map <- geo[c('Time_common', 'lat', 'lon', tracer)]
      geo_map <- na.omit(geo_map)
      
      lati_grid <- seq(-90, 90, by = 0.0005)
      long_grid <- seq(-180, 180, by = 0.0005)
      
      geo_map <- geo_map %>%
        arrange(Time_common) %>%
        mutate(lati_idx = find_neighbor(lat, lati_grid),
               long_idx = find_neighbor(lon, long_grid)) %>%
        group_by(lati_idx, long_idx) %>%
        summarize_all(funs(mean(., na.rm = T))) %>%
        ungroup() %>%
        select(-lati_idx, -long_idx)
      
      minmax <- c(min(geo_map[tracer]), max(geo_map[tracer]))
      
      cols <- geo_map[[tracer]]
      cols[cols < minmax[1]] <- minmax[1]
      cols[cols > minmax[2]] <- minmax[2]
      
      cpal <- colorNumeric(c('blue', 'cyan', 'green', 'yellow', 'orange', 'red'),
                           seq(minmax[1], minmax[2], length.out=64))
      
      pop <- paste(sep='<br>',
                   paste(tracer, ':<b>', round(geo_map[[tracer]], 2), '</b>'),
                   paste('Time:  ', format(geo_map$Time_common, tz='MST', format='%Y-%m-%d %H:%M %Z')))
      
      l <- leaflet() %>%
        addTiles(urlTemplate='http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png') %>%
        fitBounds(lng1=max(geo_map$lon)+0.01, lat1=min(geo_map$lat)-0.01, 
                  lng2=min(geo_map$lon)-0.01, lat2=max(geo_map$lat)+0.01) %>%
        addCircles(lng=geo_map$lon, lat=geo_map$lat, radius=30, popup=pop, stroke=T, weight=2,
                   fillColor=cpal(cols), color=cpal(cols), 
                   opacity=0.3, fillOpacity=0.3) %>%
        leaflet::addLegend('bottomright', pal=cpal, values=cols, opacity=0.7)
      l
    })
  
  output$ts_co2 <- output$ts_ch4 <- output$ts_co <-
    output$ts_o3 <- output$ts_nox <- output$ts_pm25 <- renderDygraph({
      tracer <- input$view_tracer
      geo <- getGeoData()
      
      validate(need(nrow(geo) > 0, ''))
      validate(need(tracer %in% names(geo), ''))
      geo <- na.omit(geo[c(tracer, 'Time_common')])
      d <- xts(geo[tracer], geo$Time_common)
      colnames(d) <- tracer
      
      dygraph(d, xlab='Time (Local)', ylab=tracer) %>%
        dySeries(color='#222D33') %>%
        dyOptions(drawGrid=F, fillGraph=T, fillAlpha=0.3, strokeWidth=0.5) %>%
        dyRangeSelector(height=30, strokeColor='')
    })
  
  output$datapull <- downloadHandler(
    filename = function() {
      'UATAQ_Nerdmobile.zip'
    },
    content = function(file) {
      geo <- getGeoData() 
      write.csv(geo, file='UATAQ_Nerdmobile/geolocated.dat', row.names=F, quote=F)
      make_figs(geo)
      zip(file, 'UATAQ_Nerdmobile', flags='-r9X')
    }
  )
}
