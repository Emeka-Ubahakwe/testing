// severity is 0 = critical, 2 = warning

param tags object
param appId string
param actionGroupId string

var appName = last(split(appId, '/'))


var only5xx = [ 
  { name: 'statusCodeCategory', operator: 'Include', values: ['5xx'] }
]

var alerts = [
  { name: 'cpu-warning',       metric: 'CpuPercentage',    aggregation: 'Average', threshold: 70,   severity: 2, dimensions: [],      description: '${appName}: CPU above 70% for 5 min. App may slow down. Check Metrics > CpuPercentage and the load on the app.' }
  { name: 'cpu-critical',      metric: 'CpuPercentage',    aggregation: 'Average', threshold: 90,   severity: 0, dimensions: [],      description: '${appName}: CPU above 90% for 5 min. Requests are likely queuing. Check what is driving the load, or scale up.' }
  { name: 'memory-warning',    metric: 'MemoryPercentage', aggregation: 'Average', threshold: 70,   severity: 2, dimensions: [],      description: '${appName}: memory above 70% for 5 min. Watch for a leak. Check Metrics > MemoryPercentage.' }
  { name: 'memory-critical',   metric: 'MemoryPercentage', aggregation: 'Average', threshold: 90,   severity: 0, dimensions: [],      description: '${appName}: memory above 90% for 5 min. App may crash and restart. Check Metrics > RestartCount.' }
  { name: 'response-warning',  metric: 'ResponseTime',     aggregation: 'Average', threshold: 1000, severity: 2, dimensions: [],      description: '${appName}: average response over 1 second for 5 min. Can also be a cold start after scale to zero.' }
  { name: 'response-critical', metric: 'ResponseTime',     aggregation: 'Average', threshold: 3000, severity: 0, dimensions: [],      description: '${appName}: average response over 3 seconds for 5 min. Users will notice. Check CPU and the app logs.' }
  { name: '5xx-warning',       metric: 'Requests',         aggregation: 'Total',   threshold: 0,    severity: 2, dimensions: only5xx, description: '${appName}: server errors (5xx) in the last 5 min. Check logs in log-obs-sbx, table ContainerAppConsoleLogs_CL, level error.' }
  { name: '5xx-critical',      metric: 'Requests',         aggregation: 'Total',   threshold: 10,   severity: 0, dimensions: only5xx, description: '${appName}: more than 10 server errors (5xx) in 5 min. Check logs in log-obs-sbx, table ContainerAppConsoleLogs_CL, level error.' }
]


resource rules 'Microsoft.Insights/metricAlerts@2018-03-01' = [for a in alerts: {
  name: 'alert-sbx-${a.name}'
  location: 'global'
  tags: tags
  properties: {
    description: a.description
    severity: a.severity
    enabled: true
    scopes: [appId]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: a.name
          metricNamespace: 'Microsoft.App/containerApps'
          metricName: a.metric
          operator: 'GreaterThan'
          threshold: a.threshold
          timeAggregation: a.aggregation
          dimensions: a.dimensions
        }
      ]
    }
    actions: [
      { actionGroupId: actionGroupId }
    ]
  }
}]
