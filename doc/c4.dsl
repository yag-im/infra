workspace "yag" {
    model {
        gamer = person "Gamer"
        yag = softwareSystem "Cloud Gaming Platform" "Allows users to play games instantly in their browsers" {            
            appsvc = container "Apps Service" "Apps management: search, pause, resume, run, stop" "Flask" "REST API"
            datastor = container "Data Storage" "Ports sources and games bundles storage" "SSD/HDD" "Storage"
            jobs = container "Jobs" "Asynchronous jobs: trimming orphaned sessions/containers" "schedule" "Jobs"
            jukebox = container "Jukebox" "Games runner and WebRTC streamer" "WebRTC" {
                streamd = component "streamd" "WebRTC streaming daemon" "gstreamer" "WebRTC"
                runner = component "Game Runner" "" "dosbox, scummvm, wine"
            }
            jukeboxsvc = container "Jukebox Service" "Jukebox containers management: cluster state, container pause, run, stop, resume" "Flask" "REST API"
            ports = container "Ports" "Yag ports collection (games installers)" {
                dosboxRunner = component "DosBox Runner"
                scummvmRunner = component "ScummVM Runner"
                wineRunner = component "Wine Runner"
            }
            portsvc = container "Ports Service" "Ports publisher" "Flask" "REST API"
            scrapers = container "Scrapers Service" "Online Game DBs scrapers" "Python" "Tool" {
                agScraper = component "AdventureGamers Scraper" "Scrapes HTML pages from https://adventuregamers.com/"
                igdbScraper = component "IGDB Scraper" "Parses IGDB using API: https://api-docs.igdb.com/" "Python"
                mgScraper = component "MobyGames Scraper" "Scrapes HTML pages from https://www.mobygames.com/" "Python"
                qzScraper = component "QuestZone Scraper" "Scrapes HTML pages from https://questzone.ru/" "Python"
            }
            sessionsvc = container "Sessions Service" "Manages sessions" "Flask" "REST API"
            sigsvc = container "Signaling Service" "WebRTC Signaling Service" "aiohttp and WebSockets" "WebRTC"
            spa = container "Single-Page Application" "Provides cloud gaming platform functionality via the web browser." "NextJs" "Web Browser"
            sqldb = container "SQL Database" "Stores yag data: users and games info" "PostgreSQL" "Database"              
            webapp = container "Web Application" "Delivers the static content and the single page application" "NextJs"
            webproxy = container "Web Proxy Service" "Dev API Proxy Server" "nginx" "Proxy, Dev"
            yagsvc = container "Yag Macroservices" "Authentication, API proxy" "Python" "REST API" {
                authController = component "Authentication Controller" "Allows users to sign in to the system" "Flask"                
            }
        }

        appsvc -> jukeboxsvc "Queries" "JSON/HTTPS"
        appsvc -> sqldb "Queries" "SQL"
        gamer -> yag "Uses"        
        jobs -> jukeboxsvc "Queries" "JSON/HTTPS"
        jobs -> sessionsvc "Queries" "JSON/HTTPS"
        jukebox -> datastor "Mounts"
        jukeboxsvc -> jukebox "Operates" "JSON/HTTPS"
        ports -> portsvc "Uses" "JSON/HTTPS"
        ports -> datastor "Uses" {
            tags "Dev"
        }
        portsvc -> sqldb "Publishes"
        scrapers -> sqldb "Initializes" "SQL"
        sessionsvc -> appsvc "Queries" "JSON/HTTPS"
        sessionsvc -> sqldb "Queries" "SQL"
        sigsvc -> sessionsvc "Queries""JSON/HTTPS"
        spa -> webproxy "Queries" "JSON/HTTPS"{
            tags "Dev"
        }
        spa -> sigsvc "Communicates" "WebSockets" {
            tags "Prod"
        }
        spa -> webapp "Queries" "HTTPS" {
            tags "Prod"
        }
        spa -> yagsvc "Queries" "JSON/HTTPS" {
            tags "Prod"
        }
        streamd -> spa "Streams" "WebRTC"
        webapp -> spa "Delivers" "HTTPS" {
            tags "Prod"
        }
        webproxy -> webapp "Proxies / queries" "JSON/HTTPS" {
            tags "Dev"
        }
        webproxy -> yagsvc "Proxies /api queries" "JSON/HTTPS" {
            tags "Dev"
        }
        webproxy -> sigsvc "Proxies /webrtc queries" "WebSockets" {
            tags "Dev"
        }
        yagsvc -> appsvc "Queries" "JSON/HTTPS"
        yagsvc -> sqldb "Queries" "SQL"

        streamd -> sigsvc "Communicates" "WebSockets"
        spa -> authController "Queries" "JSON/HTTPS"

        deploymentEnvironment "DevelopmentFull" {            
            deploymentNode "Developer Laptop" "" "Linux, MS Windows or Apple macOS" {
                deploymentNode "Data Storage" "" "Docker" {
                    dataStorageNodeInstance = containerInstance datastor
                }
                deploymentNode "Jukebox" "" "Docker" {
                    devJukeboxNodeInstance = containerInstance jukebox
                }
                deploymentNode "SQL DB Server" "" "Docker" {
                    deploymentNode "Database Server" "" "PostgreSQL" {
                        devSqlDbInstance = containerInstance sqldb
                    }
                }                
                deploymentNode "Web Browser" "" "Chrome, Firefox, Safari, or Edge" {
                    devSpaInstance = containerInstance spa
                }
                deploymentNode "Web Proxy" "" "Docker" {
                    webproxyInstance = containerInstance webproxy
                }
                deploymentNode "IDE" "" "VSCode or IntelliJ IDEA" {
                    deploymentNode "appsvc" "" "devcontainer" {
                        deploymentNode "gunicorn" "" "Flask" {
                            devAppSvcInstance = containerInstance appsvc
                        }
                    }

                    deploymentNode "jobs" "" "devcontainer" {
                        deploymentNode "Python" "" "schedule" {
                            devJobsInstance = containerInstance jobs
                        }
                    }

                    deploymentNode "jukeboxsvc" "" "devcontainer" {
                        deploymentNode "gunicorn" "" "Flask" {
                            devJukeboxSvcInstance = containerInstance jukeboxsvc
                        }
                    }

                    deploymentNode "ports" "" "devcontainer" {
                        deploymentNode "gunicorn" "" "Flask" {
                            devPortsInstance = containerInstance ports
                        }
                    }

                    deploymentNode "portsvc" "" "devcontainer" {
                        deploymentNode "gunicorn" "" "Flask" {
                            devPortSvcInstance = containerInstance portsvc
                        }
                    }

                    deploymentNode "sessionsvc" "" "devcontainer" {
                        deploymentNode "gunicorn" "" "Flask" {
                            devSessionSvcInstance = containerInstance sessionsvc
                        }
                    }
                    
                    deploymentNode "sigsvc" "" "devcontainer" {
                        deploymentNode "aiohttp" "" "WebSockets" {
                            devSigSvcInstance = containerInstance sigsvc
                        }
                    }

                    deploymentNode "webapp" "" "devcontainer" {
                        deploymentNode "NextJS" "" "" {
                            devWebAppInstance = containerInstance webapp
                        }
                    }

                    deploymentNode "yagsvc" "" "devcontainer" {
                        deploymentNode "gunicorn" "" "Flask" {
                            devYagSvcInstance = containerInstance yagsvc
                        }
                    }
                }
            }
        }
    }

    views {

        container yag "ContainersView" {
            include *
            autolayout
        }
        

        deployment yag "DevelopmentFull" {
            include *
            exclude relationship.tag==Prod
            autoLayout lr
            description "Development Mode - All Services"
        }

        styles {
            element "REST API" {
                background #E785F0
                shape Hexagon
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Database" {
                shape Cylinder
            }
            element "Storage" {
                shape Cylinder
            }
            element "Web Browser" {
                shape WebBrowser
            }            
        }
    }
}