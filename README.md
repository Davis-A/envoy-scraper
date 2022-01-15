Just a small perl script to scrape data off an enphase envoy and provide an endpoint for prometheus metrics

To run it i use `carton` with `carton install` to get the dependencies and `carton exec perl "bin/enphase-metrics.pl" --envoy <envoy-ip>` to run it