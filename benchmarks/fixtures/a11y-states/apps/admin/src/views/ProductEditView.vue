<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router';
import { useForm } from 'vee-validate';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';

type ProductDraft = { name: string; description: string; price: number };

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const { defineField, handleSubmit, meta, isSubmitting, errors } = useForm<ProductDraft>({
  initialValues: { name: '', description: '', price: 0 },
});
const [name, nameAttrs] = defineField('name');
const [description, descriptionAttrs] = defineField('description');
const [price, priceAttrs] = defineField('price');

const onSubmit = handleSubmit(async (values) => {
  await api.put(`/products/${route.params.id}`, values);
  await router.push('/products');
});
</script>

<template>
  <form class="product-form" @submit="onSubmit">
    <label for="p-name">Name</label>
    <input id="p-name" v-model="name" v-bind="nameAttrs" :aria-invalid="!!errors.name" aria-describedby="p-name-error" />
    <p id="p-name-error" class="field-error">{{ errors.name }}</p>

    <label for="p-description">Description</label>
    <textarea id="p-description" v-model="description" v-bind="descriptionAttrs" rows="8"></textarea>

    <label for="p-price">Price</label>
    <input id="p-price" v-model.number="price" v-bind="priceAttrs" type="number" min="0" step="0.01" />

    <div class="actions">
      <span v-if="meta.dirty" class="dirty-note">Unsaved changes</span>
      <button class="btn" type="submit" :disabled="isSubmitting || !meta.dirty">{{ t('common.save') }}</button>
    </div>
  </form>
</template>

<style scoped>
.product-form {
  display: grid;
  gap: var(--space-2);
  max-width: 40rem;
}

.actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: var(--space-3);
}
</style>
