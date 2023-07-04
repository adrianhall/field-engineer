@description('A type that describes auto-scaling via Insights')
type AutoScaleSettings = {
  @description('The minimum number of scale units to provision')
  minCapacity: int?

  @description('The maximum number of scale units to provision')
  maxCapacity: int?

  @description('The CPU Percentage at which point to scale in')
  scaleInThreshold: int?

  @description('The CPU Percentage at which point to scale out')
  scaleOutThreshold: int?
}
