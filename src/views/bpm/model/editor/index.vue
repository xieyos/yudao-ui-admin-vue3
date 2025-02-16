<template>
  <ContentWrap>
    <!-- 流程设计器，负责绘制流程等 -->
    <MyProcessDesigner
      key="designer"
      v-model="xmlString"
      :value="xmlString"
      v-bind="controlForm"
      keyboard
      ref="processDesigner"
      @init-finished="initModeler"
      :additionalModel="controlForm.additionalModel"
      :model="model"
      @save="save"
    />
    <!-- 流程属性器，负责编辑每个流程节点的属性 -->
    <MyProcessPenal
      v-if="isModelerReady && modeler"
      key="penal"
      :bpmnModeler="modeler"
      :prefix="controlForm.prefix"
      class="process-panel"
      :model="model"
    />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { MyProcessDesigner, MyProcessPenal } from '@/components/bpmnProcessDesigner/package'
// 自定义元素选中时的弹出菜单（修改 默认任务 为 用户任务）
import CustomContentPadProvider from '@/components/bpmnProcessDesigner/package/designer/plugins/content-pad'
// 自定义左侧菜单（修改 默认任务 为 用户任务）
import CustomPaletteProvider from '@/components/bpmnProcessDesigner/package/designer/plugins/palette'
import * as ModelApi from '@/api/bpm/model'

defineOptions({ name: 'BpmModelEditor' })

const props = defineProps<{
  modelId?: string
  modelKey?: string
  modelName?: string
}>()

const emit = defineEmits(['success'])
const message = useMessage() // 国际化

// 表单信息
const formFields = ref<string[]>([])
const formType = ref(20)
provide('formFields', formFields)
provide('formType', formType)

const xmlString = ref<string>('') // BPMN XML
const modeler = shallowRef() // BPMN Modeler
const processDesigner = ref()
const isModelerReady = ref(false)
const controlForm = ref({
  simulation: true,
  labelEditing: false,
  labelVisible: false,
  prefix: 'flowable',
  headerButtonSize: 'mini',
  additionalModel: [CustomContentPadProvider, CustomPaletteProvider]
})
const model = ref<ModelApi.ModelVO>() // 流程模型的信息

// 初始化 bpmnInstances
const initBpmnInstances = () => {
  if (!modeler.value) return false
  try {
    const instances = {
      modeler: modeler.value,
      modeling: modeler.value.get('modeling'),
      moddle: modeler.value.get('moddle'),
      eventBus: modeler.value.get('eventBus'),
      bpmnFactory: modeler.value.get('bpmnFactory'),
      elementFactory: modeler.value.get('elementFactory'),
      elementRegistry: modeler.value.get('elementRegistry'),
      replace: modeler.value.get('replace'),
      selection: modeler.value.get('selection')
    }

    // 检查所有实例是否都存在
    return Object.values(instances).every((instance) => instance)
  } catch (error) {
    console.error('初始化 bpmnInstances 失败:', error)
    return false
  }
}

/** 初始化 modeler */
const initModeler = async (item) => {
  try {
    modeler.value = item
    // 等待 modeler 初始化完成
    await nextTick()

    // 确保 modeler 的所有实例都已经准备好
    if (initBpmnInstances()) {
      isModelerReady.value = true
      if (!props.modelId && props.modelKey && props.modelName) {
        await updateModelData(props.modelKey, props.modelName)
      }
    } else {
      console.error('modeler 实例未完全初始化')
    }
  } catch (error) {
    console.error('初始化 modeler 失败:', error)
  }
}

/** 获取默认的BPMN XML */
const getDefaultBpmnXml = (key: string, name: string) => {
  return `<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="http://www.activiti.org/processdef">
  <process id="${key}" name="${name}" isExecutable="true" />
  <bpmndi:BPMNDiagram id="BPMNDiagram">
    <bpmndi:BPMNPlane id="${key}_di" bpmnElement="${key}" />
  </bpmndi:BPMNDiagram>
</definitions>`
}

/** 添加/修改模型 */
const save = async (bpmnXml: string) => {
  try {
    if (props.modelId) {
      // 编辑模式
      const data = {
        ...model.value,
        bpmnXml: bpmnXml
      } as unknown as ModelApi.ModelVO
      await ModelApi.updateModelBpmn(data)
      emit('success')
    } else {
      // 新建模式，直接返回XML
      emit('success', bpmnXml)
    }
  } catch (error) {
    console.error('保存失败:', error)
    message.error('保存失败')
  }
}

/** 初始化 */
onMounted(async () => {
  try {
    if (props.modelId) {
      // 编辑模式
      // 查询模型
      const data = await ModelApi.getModel(props.modelId)
      model.value = {
        ...data,
        bpmnXml: undefined // 清空 bpmnXml 属性
      }
      xmlString.value = data.bpmnXml || getDefaultBpmnXml(data.key, data.name)
    } else if (props.modelKey && props.modelName) {
      // 新建模式
      xmlString.value = getDefaultBpmnXml(props.modelKey, props.modelName)
      model.value = {
        key: props.modelKey,
        name: props.modelName
      } as ModelApi.ModelVO
    }
  } catch (error) {
    console.error('初始化失败:', error)
    message.error('初始化失败')
  }
})

/** 更新模型数据 */
const updateModelData = async (key?: string, name?: string) => {
  if (key && name) {
    xmlString.value = getDefaultBpmnXml(key, name)
    model.value = {
      ...model.value,
      key: key,
      name: name
    } as ModelApi.ModelVO
    // 确保更新后重新渲染
    await nextTick()
    if (processDesigner.value?.refresh) {
      processDesigner.value.refresh()
    }
  }
}

// 监听 key 和 name 的变化
watch(
  [() => props.modelKey, () => props.modelName],
  async ([newKey, newName]) => {
    if (!props.modelId && newKey && newName && modeler.value) {
      await updateModelData(newKey, newName)
    }
  },
  { immediate: true, deep: true }
)

// 在组件卸载时清理
onBeforeUnmount(() => {
  isModelerReady.value = false
  modeler.value = null
  // 清理全局实例
  const w = window as any
  if (w.bpmnInstances) {
    w.bpmnInstances = null
  }
})

/** 获取 XML 字符串 */
const saveXML = async () => {
  if (!modeler.value) {
    return { xml: undefined }
  }
  try {
    return await modeler.value.saveXML({ format: true })
  } catch (error) {
    console.error('获取XML失败:', error)
    return { xml: undefined }
  }
}

/** 获取SVG字符串 */
const saveSVG = async () => {
  if (!modeler.value) {
    return { svg: undefined }
  }
  try {
    return await modeler.value.saveSVG()
  } catch (error) {
    console.error('获取SVG失败:', error)
    return { svg: undefined }
  }
}

/** 刷新视图 */
const refresh = () => {
  if (processDesigner.value?.refresh) {
    processDesigner.value.refresh()
  }
}

// 暴露必要的属性和方法给父组件
defineExpose({
  modeler,
  isModelerReady,
  saveXML,
  saveSVG,
  refresh
})
</script>
<style lang="scss">
.process-panel__container {
  position: absolute;
  top: 172px;
  right: 70px;
}
</style>
