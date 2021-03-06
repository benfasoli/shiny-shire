# Ben Fasoli
source('global.R')

# Header Layout ----------------------------------------------------------------
header <- dashboardHeader(
  title=div(img(src='utelogo.png', height=19),
            'Atmospheric Trace gas & Air Quality'),
  titleWidth='100%')

# Sidebar Layout ---------------------------------------------------------------
sidebar <- dashboardSidebar(disable=T)

# Body Layout ------------------------------------------------------------------
body <- dashboardBody(
  tags$head(includeCSS('styles.css'),
            HTML('<meta http-equiv="refresh" content="3600">')),
  
  fluidRow(
    column(2, valueBoxOutput('wbb_pm25', NULL)),
    column(2, valueBoxOutput('wbb_o3', NULL)),
    column(2, valueBoxOutput('wbb_co2', NULL)),
    column(2, valueBoxOutput('wbb_ch4', NULL)),
    column(2, valueBoxOutput('wbb_temp', NULL)),
    column(2, valueBoxOutput('wbb_wspd', NULL))
  ),
  
  fluidRow(
    column(6, 
           box(title=HTML('Northern Utah CO<sub>2</sub>'), width = NULL, status = 'danger',
               leafletOutput('map', height = 420))
    ),
    column(6,
           box(title=HTML('University of Utah - UATAQ Lab Trends'), width=NULL, status='danger',
               plotOutput('ts', height=420)
           )
    )
  ),
  div(style='text-align: center; font-size: 14px;',
      HTML('<i class="fa fa-question-circle"></i> For more information,',
           'visit <b>air.utah.edu</b>',
           '<br>Temperature and Wind Speed measurements courtesy of ',
           '<b>MesoWest</b>')),
  
  HTML('
    <div style="position:fixed; left: 10px; bottom: 10px; text-align: center;">
    <img src="http://air.utah.edu/~benfasoli/img/LAIR_logo.png" style="width: 250px;">
    <img src="http://air.utah.edu/~benfasoli/img/SCIF_logo.png" style="width: 100px;">
    </div>')
)

# Generate Page ----------------------------------------------------------------
dashboardPage(title='UATAQ Dashboard', skin='black',
              header, sidebar, body)