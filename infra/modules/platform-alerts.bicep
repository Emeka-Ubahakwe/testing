// severity is 0 = critical, 2 = warning

param tags object
param appId string
param actionGroupId string

var only5xx = [ 
  { name: 'statusCodeCategory', operator: 'Include', values: ['5xx'] }
]

var alerts = [
  { name: 'cpu-warning',       metric: 'CpuPercentage',    aggregation: 'Average', threshold: 70,   severity: 2, dimensions: [] }
  { name: 'cpu-critical',      metric: 'CpuPercentage',    aggregation: 'Average', threshold: 90,   severity: 0, dimensions: [] }
  { name: 'memory-warning',    metric: 'MemoryPercentage', aggregation: 'Average', threshold: 70,   severity: 2, dimensions: [] }
  { name: 'memory-critical',   metric: 'MemoryPercentage', aggregation: 'Average', threshold: 90,   severity: 0, dimensions: [] }
  { name: 'response-warning',  metric: 'ResponseTime',     aggregation: 'Average', threshold: 1000, severity: 2, dimensions: [] }
  { name: 'response-critical', metric: 'ResponseTime',     aggregation: 'Average', threshold: 3000, severity: 0, dimensions: [] }
  { name: '5xx-warning',       metric: 'Requests',         aggregation: 'Total',   threshold: 0,    severity: 2, dimensions: only5xx }
  { name: '5xx-critical',      metric: 'Requests',         aggregation: 'Total',   threshold: 10,   severity: 0, dimensions: only5xx }
]

resource rules 'Microsoft.Insights/metricAlerts@2018-03-01' = [for a in alerts: {
  name: 'alert-sbx-${a.name}'
  location: 'global'
  tags: tags
  properties: {
    description: '${a.metric} above ${a.threshold}'
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
