import { Router } from "express";
import { prisma } from "../../db/prisma";
import { authRequired } from "../../middleware/auth";
import { requireEmployeeRole } from "../../middleware/roles";
import { auditLog } from "../audit/audit.service";
import {
  PatientCreateSchema,
  PatientUpdateSchema,
  validateBirthDate,
  validateDocument,
  normalizePhone,
} from "./patient.validation";

export const patientsRouter = Router();

/**
 * LISTAR pacientes (não mostra deletados por padrão)
 * Roles: ROOT_ADMIN / HR_ADMIN / ADMIN_COORDINATION / ADMIN_EMPLOYEE / DOCTOR / NURSE / NURSE_TECH
 */
patientsRouter.get(
  "/",
  authRequired,
  requireEmployeeRole([
    "ROOT_ADMIN",
    "HR_ADMIN",
    "ADMIN_COORDINATION",
    "ADMIN_EMPLOYEE",
    "DOCTOR",
    "NURSE",
    "NURSE_TECH",
  ]),
  async (req, res) => {
    const includeDeleted = String(req.query.includeDeleted ?? "false") === "true";

    const patients = await prisma.patient.findMany({
      where: includeDeleted ? {} : { deletedAt: null },
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        name: true,
        documentType: true,
        documentId: true,
        phone: true,
        birthDate: true,
        email: true,
        createdAt: true,
        updatedAt: true,
        deletedAt: true,
        deletedByEmployeeId: true,
      },
    });

    return res.json(patients);
  }
);

/**
 * GET por ID
 */
patientsRouter.get(
  "/:id",
  authRequired,
  requireEmployeeRole([
    "ROOT_ADMIN",
    "HR_ADMIN",
    "ADMIN_COORDINATION",
    "ADMIN_EMPLOYEE",
    "DOCTOR",
    "NURSE",
    "NURSE_TECH",
  ]),
  async (req, res) => {
    const patient = await prisma.patient.findUnique({
      where: { id: req.params.id },
      select: {
        id: true,
        name: true,
        documentType: true,
        documentId: true,
        phone: true,
        birthDate: true,
        email: true,
        createdAt: true,
        updatedAt: true,
        deletedAt: true,
        deletedByEmployeeId: true,
      },
    });

    if (!patient) return res.status(404).json({ error: "not_found" });
    return res.json(patient);
  }
);

/**
 * CREATE paciente
 * Roles: ROOT_ADMIN / HR_ADMIN / ADMIN_COORDINATION / ADMIN_EMPLOYEE
 */
patientsRouter.post(
  "/",
  authRequired,
  requireEmployeeRole(["ROOT_ADMIN", "HR_ADMIN", "ADMIN_COORDINATION", "ADMIN_EMPLOYEE"]),
  async (req: any, res) => {
    const parsed = PatientCreateSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: "invalid_body", details: parsed.error.flatten() });

    const b = validateBirthDate(parsed.data.birthDate);
    if (!b.ok) return res.status(400).json({ error: "invalid_birthDate", message: b.error });

    const doc = validateDocument(parsed.data.documentType, parsed.data.documentId);
    if (!doc.ok) return res.status(400).json({ error: "invalid_document", message: doc.error });

    const phone = normalizePhone(parsed.data.phone);
    if (!phone.ok) return res.status(400).json({ error: "invalid_phone", message: phone.error });

    const created = await prisma.patient.create({
      data: {
        name: parsed.data.name,
        documentType: parsed.data.documentType,
        documentId: doc.normalized,
        phone: phone.normalized,
        birthDate: b.date,
        email: parsed.data.email ?? null,
      },
    });

    await auditLog({
      actorEmployeeId: req.user?.sub,
      action: "CREATE",
      entity: "PATIENT",
      entityId: created.id,
    });

    return res.status(201).json(created);
  }
);

/**
 * UPDATE paciente
 * Roles: ROOT_ADMIN / HR_ADMIN / ADMIN_COORDINATION / ADMIN_EMPLOYEE
 */
patientsRouter.put(
  "/:id",
  authRequired,
  requireEmployeeRole(["ROOT_ADMIN", "HR_ADMIN", "ADMIN_COORDINATION", "ADMIN_EMPLOYEE"]),
  async (req: any, res) => {
    const parsed = PatientUpdateSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: "invalid_body", details: parsed.error.flatten() });

    const existing = await prisma.patient.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: "not_found" });
    if (existing.deletedAt) return res.status(409).json({ error: "patient_deleted" });

    let birthDate = existing.birthDate;
    if (parsed.data.birthDate) {
      const b = validateBirthDate(parsed.data.birthDate);
      if (!b.ok) return res.status(400).json({ error: "invalid_birthDate", message: b.error });
      birthDate = b.date;
    }

    let documentType = existing.documentType as any;
    let documentId = existing.documentId;

    if (parsed.data.documentType) documentType = parsed.data.documentType;
    if (parsed.data.documentId || parsed.data.documentType) {
      const doc = validateDocument(documentType, parsed.data.documentId ?? documentId);
      if (!doc.ok) return res.status(400).json({ error: "invalid_document", message: doc.error });
      documentId = doc.normalized;
    }

    let phone = existing.phone;
    if (parsed.data.phone) {
      const p = normalizePhone(parsed.data.phone);
      if (!p.ok) return res.status(400).json({ error: "invalid_phone", message: p.error });
      phone = p.normalized;
    }

    const updated = await prisma.patient.update({
      where: { id: req.params.id },
      data: {
        name: parsed.data.name ?? existing.name,
        documentType,
        documentId,
        phone,
        birthDate,
        email: parsed.data.email ?? existing.email,
      },
    });

    await auditLog({
      actorEmployeeId: req.user?.sub,
      action: "UPDATE",
      entity: "PATIENT",
      entityId: updated.id,
    });

    return res.json(updated);
  }
);

/**
 * DELETE (soft delete)
 * Roles: ROOT_ADMIN / HR_ADMIN
 */
patientsRouter.delete(
  "/:id",
  authRequired,
  requireEmployeeRole(["ROOT_ADMIN", "HR_ADMIN"]),
  async (req: any, res) => {
    const existing = await prisma.patient.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: "not_found" });
    if (existing.deletedAt) return res.status(200).json({ ok: true });

    await prisma.patient.update({
      where: { id: req.params.id },
      data: {
        deletedAt: new Date(),
        deletedByEmployeeId: req.user?.sub ?? null,
      },
    });

    await auditLog({
      actorEmployeeId: req.user?.sub,
      action: "DELETE",
      entity: "PATIENT",
      entityId: req.params.id,
      meta: { soft: true },
    } as any);

    return res.json({ ok: true });
  }
);
